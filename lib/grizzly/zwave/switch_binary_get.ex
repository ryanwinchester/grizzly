defmodule ZWave.SwitchBinaryGet do
  @type t :: %__MODULE__{
          command_class: %ZWave.SwitchBinary{},
          name: :switch_binary_get,
          byte: 0x02,
          version: 1
        }

  defstruct command_class: %ZWave.SwitchBinary{},
            name: :switch_binary_get,
            byte: 0x02,
            version: 1

  defimpl ZWave.Serialize do
    def to_binary(%ZWave.SwitchBinaryGet{command_class: cc, byte: byte}) do
      {:ok, <<cc.byte, byte>>}
    end
  end

  defimpl ZWave.Deserialize do
    def from_binary(get, <<0x25, 0x02>>), do: {:ok, get}
  end
end
