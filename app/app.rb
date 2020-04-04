# encoding: utf-8

##
# Подключения к одному или нескольким кроликам хранятся в переменных:
# сессия   - Cfg.mq.имя.service.connection
# очередь  - Cfg.mq.имя.service.queue
# обменник - Cfg.mq.имя.service.exchange
# где тип service - MQService
# Чтение файлов настроек, настройка приложения, подключение к базе и запуск обработчиков команд.

require 'yaml'
require 'sequel'

require 'pry-byebug'

require_relative 'monkeys'
require_relative 'app_settings'
require_relative 'my-logger'

module App

  def self.config!
    return Cfg if defined?( Cfg ) && Cfg.respond_to?(:app)
    $shutdown = false # когда true -- выходим неспешно
    meroot ||= Pathname( __FILE__ ).dirname.parent.expand_path
    meenv  ||= (ENV['APP_ENV'] || 'development').to_sym.freeze
    meloglevel ||= Kernel.const_get("Logger::#{ ENV['LOG_LEVEL'].upcase }") rescue ( meenv == :production ? Logger::WARN : Logger::DEBUG )
    Dir.chdir meroot
    # Список семафоров для ожидания ответов от сервисов.
    $bbs = {}
    # Все настройки приложения; роуты -- отдельно.
    Kernel.const_set 'Cfg', AppSettings.new( YAML.load_file("#{ meroot }/config/cfg.#{ meenv }.yml") )
    raise "Не нашёл файла настроек в #{ meroot }/config/" if Cfg.empty?
    Cfg.root = meroot
    Cfg.env  = meenv
    Cfg.loglevel = meloglevel
    Cfg
  end

  def self.logger!
    MyLogger.start
  end

  def self.dbconn!
    # кешированное подключение к базе данных
    if (! defined? @@db) || (@@db.nil?) || (! @@db) || (! @@db.test_connection)
      Log.info{ "PostgreSQL БД #{ Cfg.db.database }." }
      Sequel.extension :pg_array, :pg_inet, :pg_json, :pg_json_ops, :pg_array, :pg_array_ops, :pg_row, :pg_hstore, :pg_json_ops
      Sequel::Model.raise_on_save_failure = false
      Sequel::Model.plugin :validation_helpers
      Sequel::Database.extension :pg_inet, :pg_json, :pg_array, :pg_range, :pg_row, :pg_enum
      Cfg.app.tmout.database_start.times do
        begin
          @@db = Sequel.connect Cfg.db.to_hash
          break
        rescue Sequel::DatabaseConnectionError => e
          Log.warn{"Error connecting to Postgresql. #{ ( s = e.message.dup ).force_encoding('UTF-8') }"}
          sleep 1
        end
      end
      Kernel.const_set 'Db', @@db
      Sequel::Model.db = Db
      Db.freeze if Cfg.env == :production
    end
    return @@db
  end

  def self.shutdown
    Log.warn{ "Выключение." }
    # Db.quit
  end

  def self.init!
    config!
    logger!
    dbconn!
#  trap('INT') { $shutdown = true }
#  trap('TERM') { $shutdown = true }
  end

end
