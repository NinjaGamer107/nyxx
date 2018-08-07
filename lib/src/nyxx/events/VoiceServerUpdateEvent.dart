part of nyxx;

/// Emitted when guild's voice server changes
class VoiceServerUpdateEvent {
  String token;
  Guild guild;
  String endpoint;

  Map<String, dynamic> raw;

  VoiceServerUpdateEvent._new(Client client, this.raw) {
    this.token = raw['d']['token'] as String;
    this.guild = client.guilds[new Snowflake(raw['d']['guild_id'] as String)];
    this.endpoint = raw['d']['endpoint'] as String;

    client._events.onVoiceServerUpdate.add(this);
  }
}