defmodule ZWave.SwitchBinary do
  @type t :: %__MODULE__{byte: 0x25, name: :command_class_switch_binary}
  defstruct byte: 0x25, name: "COMMAND_CLASS_SWITCH_BINARY"
end
