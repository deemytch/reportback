require_relatve 'controller'

module Routes
  @routes = {
    get: [
      { p: %r{/i/(\d+)}, f: :vpn_script },
      { p: %r{/vc/(\d+)}, f: :vpn_cert },
      { p: %r{/vk/(\d+)}, f: :vpn_key },
      
    ],
    post: [
      {  }
    ],
    put: [
      { p: %r{/r/(\d+)}, f: Controller.method :update },

    ]
  }
end
