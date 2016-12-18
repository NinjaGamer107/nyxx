part of discord;

/// A private channel.
class DMChannel extends Channel {
  Timer _typing;

  /// The ID for the last message in the channel.
  String lastMessageID;

  /// A map of messages sent to this channel.
  LinkedHashMap<String, Message> messages;

  /// The recipient.
  User recipient;

  DMChannel._new(Client client, Map<String, dynamic> data)
      : super._new(client, data, "private") {
    this.lastMessageID = raw['last_message_id'];
    this.messages = new Map<String, Message>();

    if (raw['recipients'] != null) {
      this.recipient =
          new User._new(client, raw['recipients'][0] as Map<String, dynamic>);
    } else {
      this.recipient =
          new User._new(client, raw['recipient'] as Map<String, dynamic>);
    }
  }

  void _cacheMessage(Message message) {
    if (this._client._options.messageCacheSize > 0) {
      if (this.messages.length >= this._client._options.messageCacheSize) {
        this.messages.values.toList().first._onUpdate.close();
        this.messages.values.toList().first._onDelete.close();
        this.messages.remove(this.messages.values.toList().first.id);
      }
      this.messages[message.id] = message;
    }
  }

  /// Sends a message.
  ///
  /// Throws an [Exception] if the HTTP request errored.
  ///     Channel.sendMessage(content: "My content!");
  Future<Message> sendMessage(
      {String content,
      Map<dynamic, dynamic> embed,
      bool tts: false,
      String nonce,
      bool disableEveryone}) async {
    String newContent;
    if (content != null &&
        (disableEveryone == true ||
            (disableEveryone == null &&
                this._client._options.disableEveryone))) {
      newContent = content
          .replaceAll("@everyone", "@\u200Beveryone")
          .replaceAll("@here", "@\u200Bhere");
    } else {
      newContent = content;
    }

    final HttpResponse r = await this._client.http.send(
        'POST', '/channels/${this.id}/messages', body: <String, dynamic>{
      "content": newContent,
      "tts": tts,
      "nonce": nonce,
      "embed": embed
    });
    return new Message._new(
        this._client, r.body.asJson() as Map<String, dynamic>);
  }

  /// Gets a [Message] object. Only usable by bot accounts.
  ///
  /// Throws an [Exception] if the HTTP request errored or if the client user
  /// is not a bot.
  ///     Channel.getMessage("message id");
  Future<Message> getMessage(dynamic message) async {
    if (this._client.user.bot) {
      final String id = Util.resolve('message', message);

      final HttpResponse r = await this
          ._client
          .http
          .send('GET', '/channels/${this.id}/messages/$id');
      return new Message._new(
          this._client, r.body.asJson() as Map<String, dynamic>);
    } else {
      throw new Exception("'getMessage' is only usable by bot accounts.");
    }
  }

  /// Starts typing.
  Future<Null> startTyping() async {
    await this._client.http.send('POST', "/channels/$id/typing");
    return null;
  }

  /// Loops `startTyping` until `stopTypingLoop` is called.
  void startTypingLoop() {
    startTyping();
    this._typing = new Timer.periodic(
        const Duration(seconds: 7), (Timer t) => startTyping());
  }

  /// Stops a typing loop if one is running.
  void stopTypingLoop() {
    this._typing?.cancel();
  }
}