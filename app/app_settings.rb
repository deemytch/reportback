require 'hashie'

class AppSettings < Hashie::Mash
  include Hashie::Extensions::IndifferentAccess
  include Hashie::Extensions::DeepMerge
end
