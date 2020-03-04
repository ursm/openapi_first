# frozen_string_literal: true

require 'rack'

module OpenapiFirst
  class App
    def initialize(
      app,
      spec,
      namespace:
    )
      @stack = Rack::Builder.app do
        freeze_app
        use OpenapiFirst::Router,
            spec: spec,
            namespace: namespace
        use OpenapiFirst::RequestValidation
        run OpenapiFirst::OperationResolver.new
      end
    end

    def call(env)
      @stack.call(env)
    end
  end
end
