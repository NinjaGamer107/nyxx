part of nyxx;

/// Sent when a message is deleted.
class MessageDeleteEvent {
  /// The message, if cached.
  Message message;

  /// The ID of the message.
  Snowflake id;

  MessageDeleteEvent._new(Client client, Map<String, dynamic> json) {
    if (client.ready) {
      if ((client.channels[new Snowflake(json['d']['channel_id'] as String)] as MessageChannel)
              .messages[new Snowflake(json['d']['id'] as String)] !=
          null) {
        this.message =
            (client.channels[new Snowflake(json['d']['channel_id'] as String)] as MessageChannel)
                .messages[new Snowflake(json['d']['id'] as String)];
        this.id = message.id;
        this.message._onDelete.add(this);
        client._events.onMessageDelete.add(this);
      } else {
        this.id = new Snowflake((json['d']['id'] as String));
        if (!client._options.ignoreUncachedEvents) {
          client._events.onMessageDelete.add(this);
        }
      }
    }
  }
}