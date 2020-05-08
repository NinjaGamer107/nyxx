part of nyxx.commander;

/// Used to determine if command can be executed in given environment.
/// Return true to allow executing command or false otherwise.
typedef FutureOr<bool> PassHandlerFunction(CommandContext context, String message);

/// Handler for executing command logic.
typedef FutureOr<void> CommandHandlerFunction(CommandContext context, String message);

/// Handler used to determine prefix for command in given environment.
/// Can be used to define different prefixes for different guild, users or dms.
/// Return String containing prefix or null if command cannot be executed.
typedef FutureOr<String?> PrefixHandlerFunction(CommandContext context, String message);

/// Callback to customize logger output when command is executed.
typedef FutureOr<void> LoggerHandlerFunction(CommandContext context, String commandName, Logger logger);

/// Lightweight command framework. Doesn't use `dart:mirrors` and can be used in browser.
/// While constructing specify prefix which is string with prefix or 
/// implement [PrefixHandlerFunction] for more fine control over where and in what conditions commands are executed.
/// 
/// Allows to specify callbacks which are executed before and after command - also on per command basis.
/// [BeforeHandlerFunction] callbacks are executed only command exists and is matched with message content.
class Commander {
  late final PrefixHandlerFunction _prefixHandler;
  late final PassHandlerFunction? _beforeComandHandler;
  late final CommandHandlerFunction? _afterHandlerFunction;
  late final LoggerHandlerFunction _loggerHandlerFunction;

  List<CommandHandler> _commands = [];
  
  Logger _logger = Logger("Commander");

  /// Either [prefix] or [prefixHandler] must be specified otherwise program will exit.
  /// Allows to specify additional [beforeCommandHandler] executed before main command callback,
  /// and [afterCommandCallback] executed after main command callback.
  Commander(Nyxx client, {String? prefix, PrefixHandlerFunction? prefixHandler,
    PassHandlerFunction? beforeCommandHandler, CommandHandlerFunction? afterCommandHandler,
    LoggerHandlerFunction? loggerHandlerFunction}) {

    if(prefix == null && prefixHandler == null) {
      _logger.shout("Commander cannot start without both prefix and prefixHandler");
      exit(1);
    }

    if(prefix == null) {
      _prefixHandler = prefixHandler!;
    } else {
      _prefixHandler = (ctx, msg) => prefix;
    }

    this._beforeComandHandler = beforeCommandHandler;
    this._afterHandlerFunction = afterCommandHandler;

    this._loggerHandlerFunction = loggerHandlerFunction ?? _defaultLogger;

    client.onMessageReceived.listen(_handleMessage);
  }

  FutureOr<void> _defaultLogger(CommandContext ctx, String commandName, Logger logger) {
    logger.info("Command [$commandName] executed by [${ctx.author!.tag}]");
  }

  Future<void> _handleMessage(MessageReceivedEvent event) async {
    if(event.message == null) {
      return;
    }

    var context = CommandContext._new(event.message.channel,
        event.message.author,
        event.message is GuildMessage ? (event.message as GuildMessage).guild : null,
        event.message);

    var prefix = await _prefixHandler(context, event.message.content);
    if(prefix == null) {
      return;
    }

    CommandHandler? matchingCommand = _commands.firstWhere((element) => _isCommandMatching(
        element.commandName, event.message.content.replaceFirst(prefix, "")), orElse: () => null);

    if(matchingCommand == null) {
      return;
    }

    if(this._beforeComandHandler != null && !await this._beforeComandHandler!(context, event.message.content)) {
      return;
    }

    if(matchingCommand.beforeHandler != null && !await matchingCommand.beforeHandler!(context, event.message.content)){
      return;
    }

    await matchingCommand.commandHandler(context, event.message.content);

    // execute logger callback
    _loggerHandlerFunction(context, matchingCommand.commandName, this._logger);
    
    if(matchingCommand.afterHandler != null) {
      await matchingCommand.afterHandler!(context, event.message.content);
    }

    if(this._afterHandlerFunction != null) {
      this._afterHandlerFunction!(context, event.message.content);
    }
  }

  /// Registers command with given [commandName]. Allows to specify command specific before and after command execution callbacks
  void registerCommand(String commandName, CommandHandlerFunction commandHandler, {PassHandlerFunction? beforeHandler, CommandHandlerFunction? afterHandler}) {
    this._commands.add(_InternalCommandHandler(commandName, commandHandler, beforeHandler: beforeHandler, afterHandler: afterHandler));
  }

  /// Registers command as implemented [CommandHandler] class
  void registerCommandClass(CommandHandler commandHandler) => this._commands.add(commandHandler);
}