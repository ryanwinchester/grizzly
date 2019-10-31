defmodule ZWave.Deserializer do
  @callback from_binary(binary()) :: {:ok, ZWave.Deserialize.t()}

  def from_binary(deserializer, binary), do: deserializer.from_binary(binary)
end
