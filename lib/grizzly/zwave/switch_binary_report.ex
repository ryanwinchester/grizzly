defmodule ZWave.SwitchBinaryReport do
  @type switch_value :: :on | :off | 1..99
  @type duration :: byte()

  @type t :: %__MODULE__{
          value: switch_value(),
          target_value: switch_value() | nil,
          duration: duration() | nil,
          command_class: %ZWave.SwitchBinary{},
          name: :switch_binary_report,
          byte: 0x03,
          version: 1 | 2
        }

  defstruct value: nil,
            target_value: nil,
            duration: nil,
            command_class: %ZWave.SwitchBinary{},
            name: :switch_binary_report,
            byte: 0x03,
            version: nil

  defimpl ZWave.Deserialize do
    def from_binary(_data, <<_cc_byte, _command_byte, value>>),
      do: %ZWave.SwitchBinaryReport{value: value, version: 1}

    def from_binary(_data, <<_cc_byte, _command_byte, value, target_value, duration>>),
      do: %ZWave.SwitchBinaryReport{
        value: value,
        target_value: target_value,
        duration: duration,
        version: 2
      }
  end

  defimpl ZWave.Serialize do
    def to_binary(
          %ZWave.SwitchBinaryReport{value: value, target_value: tv, duration: duration} = command
        ) do
      <<command.command_class.byte, command.byte, value>>
      |> maybe_append_byte(tv)
      |> maybe_append_byte(duration)
    end

    defp maybe_append_byte(_binary, nil), do: nil
    defp maybe_append_byte(binary, value), do: binary <> <<value>>
  end
end
