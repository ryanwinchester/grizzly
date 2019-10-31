defprotocol ZWave.Deserialize do
  def from_binary(data, t)
end

defmodule ZWave.Deserializer.Default do
  @moduledoc false

  @behaviour ZWave.Deserializer

  alias ZWave.{
    SwitchBinarySet,
    SwitchBinaryGet,
    SwitchBinaryReport
  }

  def from_binary(<<0x25, 0x01, _::binary>> = binary),
    do: ZWave.Deserialize.from_binary(%SwitchBinarySet{}, binary)

  def from_binary(<<0x25, 0x02, _::binary>> = binary),
    do: ZWave.Deserialize.from_binary(%SwitchBinaryGet{}, binary)

  def from_binary(<<0x25, 0x04, _::binary>> = binary),
    do: ZWave.Deserialize.from_binary(%SwitchBinaryReport{}, binary)
end
