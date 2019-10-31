defmodule Grizzly.CommandClass.SwitchBinary.Get do
  @moduledoc """
  Command module for working with SWITCH_BINARY GET command.

  command options:

    * `:seq_number` - The sequence number for the Z/IP Packet
    * `:retries` - The number of times to resend the command (default 2)
  """
  @behaviour Grizzly.CommandNG.Command

  alias Grizzly.Packet
  alias ZWave.SwitchBinaryGet

  @spec init(any) :: {:ok, SwitchBinaryGet.t(), map()}
  def init(_) do
    {:ok, %SwitchBinaryGet{}, %{}}
  end

  @spec handle_ack(map()) :: {:continue, map()}
  def handle_ack(state), do: {:continue, state}

  @spec handle_command(Packet.t(), SwitchBinaryGet.t(), map()) :: {:done, {:ok, :on | :off}}
  def handle_command(
        %Packet{
          body: %{command_class: :switch_binary, command: :report, value: switch_state}
        },
        _get_command,
        _state
      ),
      do: {:done, {:ok, switch_state}}

  def handle_command(_), do: {:continue, %{}}
end
