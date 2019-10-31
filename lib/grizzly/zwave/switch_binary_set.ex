defmodule ZWave.SwitchBinarySet do
  @type t :: %__MODULE__{
          value: switch_value,
          duration: duration | nil,
          name: :switch_binary_set,
          byte: 0x01,
          version: 1 | 2,
          command_class: %ZWave.SwitchBinary{}
        }

  @type switch_value :: :on | :off | 1..99
  @type duration :: byte()

  @type opt :: {:value, switch_value()} | {:duration, duration()}

  defstruct value: nil,
            duration: nil,
            command_class: %ZWave.SwitchBinary{},
            byte: 0x01,
            name: :switch_binary_set,
            version: nil

  @spec new([opt]) :: t()
  def new(opts) do
    # we can do more options validation stuff here
    if Keyword.has_key?(opts, :duration) do
      __MODULE__
      |> struct(opts)
      |> struct(version: 2)
    else
      __MODULE__
      |> struct(opts)
      |> struct(version: 1)
    end
  end

  defimpl ZWave.Serialize do
    def to_binary(%ZWave.SwitchBinarySet{
          command_class: cc,
          value: value,
          byte: byte,
          duration: duration
        }) do
      value = serialize_value(value)

      binary =
        <<cc.byte, byte, value>>
        |> maybe_append_byte(duration)

      {:ok, binary}
    end

    defp maybe_append_byte(binary, nil), do: binary
    defp maybe_append_byte(binary, byte), do: <<binary>> <> byte

    defp serialize_value(:on), do: 0xFF
    defp serialize_value(:off), do: 0x00
    defp serialize_value(value) when value in 1..99, do: value
  end

  defimpl ZWave.Deserialize do
    def from_binary(_, <<0x25, 0x03, value>>) do
      {:ok, %ZWave.SwitchBinarySet{value: deserialize_value(value), version: 1}}
    end

    def from_binary(_, <<0x25, 0x03, value, duration>>) do
      {:ok,
       %ZWave.SwitchBinarySet{value: deserialize_value(value), version: 2, duration: duration}}
    end

    defp deserialize_value(0xFF), do: :on
    defp deserialize_value(0x00), do: :off
    defp deserialize_value(value) when value in 1..99, do: value
  end
end
