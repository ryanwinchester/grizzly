defmodule Grizzly.CommandClass.SwitchBinary.Set do
  @moduledoc """
  Command module for working with SWITCH_BINARY SET command.

  command options:

    * `:value` - either `:on` or `:off`, or a number between 1 and 99 inclusive (required)
    * `:duration` - the time in duration of seconds or minutes (optional)
  """
  @behaviour Grizzly.CommandNG.Command

  alias ZWave.SwitchBinarySet

  defstruct value: nil

  @type opts ::
          {:value, SwitchBinarySet.switch_value()} | {:duration, SwitchBinarySet.duration()}

  @spec init([opts]) :: {:ok, any()}
  def init(opts) do
    switch_set = SwitchBinarySet.new(opts)
    {:ok, switch_set, nil}
  end

  @spec handle_ack(state :: any()) :: {:done, :ok}
  def handle_ack(_state), do: {:done, :ok}

  @spec handle_command(Packet.t(), ZWave.Serialize.t(), state) :: {:continue, state}
        when state: any()
  def handle_command(_, _, state), do: {:continue, state}
end
