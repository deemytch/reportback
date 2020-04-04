require 'rack'
require_relative 'routes'

class Router
  include Routes
  def initialize( env )
    @request = Rack::Request.new( env )
    @payload = case @request.content_type
              when /json$/
                JSON.decode @request.body.read
              when /yaml$/
                YAML.load @request.body.read
              else
                plain_text @request.body.read
              end
    Log.info{"#{ request.user_agent }:#{ request.ip } #{ request.request_method } #{ request.path }\ncontent-type: #{ request.content_type }\n#{ payload ? payload : '-' }\n===."}
  end

  def arbeiten
    response call_controller find_route
  end

  # Жёсткий выбор по HTTP-методу
  def find_route
    @params = {}
    ( route = @@routes[ request.request_method.to_s.to_lower ].find &compare_route ) ?
      ( Log.debug{ "route: #{ request_method.to_s.to_lower } #{ x[:p] } #{ request.path } " };
        route[:f].respond_to?(:new) ? route[:f].new( @request, @params, @payload ) : route[:f] ) : nil
  end

  def compare_route( x )
    if x.key?(:p) # path
      return nil unless @request.path === x[:p]
      @params[:id] = $1
    end
    if x.key?(:a) # user-agent
      return nil unless @request.user_agent === x[:a]
    end
    return x.key?( :f ) ? x[ :f ] : {|r, p, b| :ok }
  end

  def call_controller( y )
    case y
    when Proc then y.( @request, @params, @payload)
    when Symbol then Controller.new( @request, @params, @payload ).send(y)
    when String then eval(y)
    else
      nil
    end
  end

  def plain_text( s )
    s.force_encoding( @request.content_encoding || 'UTF-8')
  end

  def response(code, body = nil)
    [
      ({ not_found: 404, async: -1, ok: 200, created: 201, invalid: 422 }[code] || 422),
      { "Content-Type" => 'text/plain' },
      [ body ? body : code.to_s ]
    ]
  end
end
