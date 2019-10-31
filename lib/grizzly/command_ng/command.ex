defmodule Grizzly.CommandNG.Command do
  @moduledoc """
  Command is a server managing the overall lifecycle of the execution of a command,
  from start to completion or timeout.

  When starting the execution of a command, the state of the network is checked to see if it is
  in one of the allowed states for executing this particular command. The allowed states are listed
  in the `pre_states` property of the command being started. If the property is absent, the default
  allowed states are [:idle]. If the network is not in an allowed state, {:error, :network_busy} is returned.

  If the started command has an `exec_state` property, the network state is set to its value for the duration
  of the execution of the command. If there is none, the network state is unchanged.

  If the started command has a `post_state` property, the network state is set to it after the command execution
  completes or times out. If there is none, the network state is set to :idle.

  If the started command has a `timeout` property, a timeout is set to its value. If the command does not complete
  before the timeout expires, the command's execution is stopped and a {:timeout, <command module>} message is sent to
  the process that started the execution of the command.
  """

  use GenServer

  alias Grizzly.{Packet, SeqNumber}
  alias Grizzly.Network.State, as: NetworkState
  alias Grizzly.Command.EncodeError
  require Logger

  @type t :: pid

  @type handle_instruction ::
          {:continue, state :: any()}
          | {:continue, ZWave.Serialize.t(), state :: any()}
          | {:done, response :: any()}
          | {:send_message, message :: any(), state :: any()}

  @callback init(args :: term) :: :ok | {:ok, ZWave.Serialize.t(), state :: any()}

  @callback handle_ack(state :: any()) :: handle_instruction()

  @callback handle_command(Packet.t(), ZWave.Serialize.t(), state :: any()) :: handle_instruction

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            command_module: module(),
            command_state: any(),
            command: ZWave.Serialize.t(),
            retries: non_neg_integer(),
            timeout_ref: pid,
            seq_number: Grizzly.seq_number(),
            starter: pid
          }

    defstruct command_module: nil,
              command_state: nil,
              command: nil,
              retries: 2,
              seq_number: 0,
              timeout_ref: nil,
              starter: nil
  end

  @spec start(module, opts :: keyword) :: GenServer.on_start() | {:error, :network_busy}
  def start(module, opts) do
    _ = Logger.debug("Starting command #{inspect(module)} with args #{inspect(opts)}")

    {:ok, command, state} = apply(module, :init, [opts])

    if not NetworkState.in_allowed_state?(Map.get(state, :pre_states)) do
      _ =
        Logger.warn(
          "Command #{module} not starting in allowed network states #{
            inspect(Map.get(state, :pre_states))
          }"
        )

      {:error, :network_busy}
    else
      seq_number = SeqNumber.get_and_inc()
      retries = Keyword.get(opts, :retries, 2)
      :ok = NetworkState.set(Map.get(state, :exec_state))

      GenServer.start(
        __MODULE__,
        command_module: module,
        command: command,
        command_state: state,
        starter: self(),
        seq_number: seq_number,
        retries: retries
      )
    end
  end

  @spec encode(t) :: {:ok, binary} | {:error, EncodeError.t()}
  def encode(command) do
    GenServer.call(command, :encode)
  end

  @spec handle_response(t, Packet.t()) ::
          {:finished, value :: any()}
          | :continue
          | :retry
          | :queued
          | {:send_message, message :: any()}
  def handle_response(command, packet) do
    GenServer.call(command, {:handle_response, packet}, 60_000 * 2)
  end

  @spec complete(t) :: :ok
  def complete(command) do
    GenServer.call(command, :complete)
  end

  @impl true
  def init(args) do
    command_state = Keyword.get(args, :command_state)
    command = Keyword.get(args, :command)
    timeout_ref = setup_timeout(Map.get(command, :timeout))
    command_module = Keyword.get(args, :command_module)
    starter = Keyword.get(args, :starter)
    seq_number = Keyword.get(args, :seq_number)
    retries = Keyword.get(args, :retries)

    {
      :ok,
      %State{
        command_module: command_module,
        command_state: command_state,
        command: command,
        timeout_ref: timeout_ref,
        starter: starter,
        seq_number: seq_number,
        retries: retries
      }
    }
  end

  @impl true
  def terminate(:normal, _state) do
    :ok
  end

  def terminate(reason, %State{command: command}) do
    _ =
      Logger.warn(
        "Command #{inspect(command)} terminated with #{inspect(reason)}. Resetting network state to idle"
      )

    NetworkState.set(:idle)
    :ok
  end

  # Upon command completion, clear any timeout and
  # set the network state to what the command specifies (defaults to :idle).
  @impl true
  def handle_call(:complete, _from, %State{command: command, timeout_ref: timeout_ref} = state) do
    _ = clear_timeout(timeout_ref)

    post_state = Map.get(command, :post_state, :idle)
    NetworkState.set(post_state)

    {:stop, :normal, :ok, %State{state | timeout_ref: nil}}
  end

  def handle_call(
        :encode,
        _,
        %State{command: command, seq_number: seq_number} = state
      ) do
    case ZWave.to_binary(command) do
      {:ok, binary} ->
        binary = Packet.header(seq_number) <> binary
        {:reply, {:ok, binary}, state}

      {:error, _} = error ->
        {:stop, :normal, error, state}
    end
  end

  def handle_call(
        {:handle_response, %Packet{seq_number: seq_number, types: [:ack_response]} = packet},
        _from,
        %State{
          seq_number: seq_number,
          command_module: command_module,
          command_state: command_state
        } = state
      ) do
    case apply(command_module, :handle_ack, [command_state]) do
      {:done, value} ->
        {:reply, {:finished, value}, state}

      {:continue, new_command_state} ->
        {:reply, :continue, %{state | command_state: new_command_state}}
    end
  end

  def handle_call(
        {:handle_response, %Packet{seq_number: seq_number, types: [:nack_response]}},
        _from,
        %State{seq_number: seq_number, retries: 0} = state
      ) do
    {:reply, {:finished, {:error, :nack_response}}, state}
  end

  def handle_call(
        {:handle_response, %Packet{seq_number: seq_number, types: [:nack_response]}},
        _from,
        %State{seq_number: seq_number, retries: n} = state
      ) do
    {:reply, :retry, %{state | retries: n - 1}}
  end

  def handle_call(
        {:handle_response,
         %Packet{seq_number: seq_number, types: [:nack_response, :nack_waiting]} = packet},
        _from,
        %State{seq_number: seq_number} = state
      ) do
    if Packet.sleeping_delay?(packet) do
      {:reply, :queued, state}
    else
      {:reply, :continue, state}
    end
  end

  def handle_call(
        {:handle_response, %Packet{} = packet},
        _from,
        %State{command_module: command_module, command: command, command_state: command_state} =
          state
      ) do
    case apply(command_module, :handle_command, [packet, command, command_state]) do
      {:done, value} ->
        {:reply, {:finished, value}, state}

      {:send_message, message, new_command} ->
        {:reply, {:send_message, message}, %{state | command: new_command}}
    end
  end

  @impl true
  def handle_info(:timeout, %State{starter: starter, command_module: command_module} = state) do
    send(starter, {:timeout, command_module})
    {:stop, :normal, %State{state | timeout_ref: nil}}
  end

  defp setup_timeout(nil), do: nil

  defp setup_timeout(timeout) do
    Process.send_after(self(), :timeout, timeout)
  end

  defp clear_timeout(nil), do: :ok
  defp clear_timeout(timeout_ref), do: Process.cancel_timer(timeout_ref)
end
