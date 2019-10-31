defprotocol ZWave.Serialize do
  def to_binary(command)
end
