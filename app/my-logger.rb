require 'logger'

module MyLogger
  def self.start( dest = Cfg.app.log )
    return if defined?(Log)
    case dest
      when 'stderr', 'syslog'
        logger {
          $stdout.close
          $stdout = $stderr
        }
      when 'stdout'
        logger {
          $stderr.close
          $stderr = $stdout
        }
      else
        logger {
          Cfg.app.log = "#{ Cfg.root }/#{ Cfg.app.log }" unless Cfg.app.log =~ %r{^/}
          FileUtils.mkdir_p Pathname.new( Cfg.app.log ).dirname
          logf = File.open( Cfg.app.log, 'a' )
          logf.sync = true
          $stderr.reopen logf
          $stdout.reopen logf
          logf
        }
    end
    Log.info{"#{ Cfg.env } started."}
  end

  def self.mq_formatter
    # Убираем некоторую вредность из логгера Кролика
    original_formatter = Logger::Formatter.new
    return proc { |severity, datetime, progname, msg|
      if msg !~ /Using TLS but no client certificate is provided/ && severity != 'DEBUG'
        msg.force_encoding('UTF-8')
        msg += "\n===BACKTACE:===\n#{ caller.join("\n") }\n===" if severity == 'ERROR'
        original_formatter.call(severity, datetime, progname, msg )
      end
    }
  end

  def self.logger( &block )
    logdev = yield    
    Kernel.const_set 'Log', Logger.new( logdev, progname: Cfg.app.progname, level: Cfg.loglevel )
    Kernel.const_set 'MQLog', Logger.new( logdev, progname: "#{ Cfg.app.progname }+Bunny", level: Cfg.loglevel, formatter: mq_formatter )
  end

end
