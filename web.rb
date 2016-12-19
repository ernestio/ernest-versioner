require 'sinatra/base'

module ErnestBot
  # Web base class
  class Web < Sinatra::Base
    get '/' do
      'Go ernest go!'
    end
  end
end
