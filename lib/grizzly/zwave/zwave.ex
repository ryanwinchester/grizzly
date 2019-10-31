defmodule ZWave do
  @type deserialize_opt :: {:deserializer, module()}

  @spec to_binary(ZWave.Serialize.t()) :: {:ok, binary()}
  def to_binary(serializeable), do: ZWave.Serialize.to_binary(serializeable)

  @spec from_binary(binary(), [deserialize_opt]) :: {:ok, ZWave.Deserialize.t()}
  def from_binary(binary, opts \\ []) do
    deserializer = Keyword.get(opts, :deserializer, ZWave.Deserializer.Default)

    ZWave.Deserializer.from_binary(deserializer, binary)
  end
end
