# frozen_string_literal: true

require_relative 'has_content'

module OpenapiFirst
  class RequestBody
    include HasContent

    def initialize(request_body_object, operation)
      @object = request_body_object
      @operation = operation
    end

    def description
      @object['description']
    end

    def required?
      !!@object['required']
    end

    private

    def schema_write?
      @operation.write?
    end

    def content
      @object['content']
    end
  end
end
