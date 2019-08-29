class Controller
  def initialize( request, params, payload )
    @request = request
    @params  = params
    @payload = payload
  end

  def update
    unless r = Report[ @params[:id] ]
      Log.error{"Запрошено обновление неизвестного отчёта #{ @params[:id] }."}
      return :invalid
    end
    Log.info{"Update #{ @params[:id] } => #{ @request.ip }, #{ @payload[:hostname] }."}
    r.update( hardware: @payload, ip: @request.ip )
    :ok
  end

  def vpn_script
    unless Report[ @params[:id] ]
      Log.error{"Запроc неизвестного клиента #{ @params[:id] }."}
      return :invalid
    end
    script_vpn = File.read( "#{ Cfg.root }/#{ Cfg.app.script_vpn }" ).gsub(/\$\$[a-zA-Z\._]+/){|e| eval e.gsub(/\$\$/,'') }
    return [ :ok, script_vpn ]
  end

  def vpn_cert
    unless Report[ params[:id] ]
      Log.error{"Запрошен персональный сертификат неизвестного клиента #{ params[:id] }."}
      return :invalid
    end
    cert = File.read( "/etc/openvpn/easy-rsa/pki/issued/#{ Report[ params[:id] ].cert }.crt" )
    return [ :ok, cert ]
  end

  def vpn_key
    unless Report[ params[:id] ]
      Log.error{"Запрошен персональный ключ сертификата неизвестного клиента #{ params[:id] }."}
      return respond(:invalid)
    end
    key = File.read( "/etc/openvpn/easy-rsa/pki/private/#{ Report[ params[:id] ].cert }.key" )
    return [ :ok, key ]
  end

  def 

end
