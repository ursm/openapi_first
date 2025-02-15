# frozen_string_literal: true

require 'multi_json'
require_relative 'use_router'

module OpenapiFirst
  class ResponseValidation
    prepend UseRouter

    def initialize(app, _options = {})
      @app = app
    end

    def call(env)
      operation = env[OPERATION]
      return @app.call(env) unless operation

      response = @app.call(env)
      validate(response, operation)
      response
    end

    def validate(response, operation)
      status, headers, body = response.to_a
      response_definition = response_for(operation, status)

      validate_response_headers(response_definition.headers, headers, openapi_version: operation.openapi_version)

      return if no_content?(response_definition)

      content_type = Rack::Response[status, headers, body].content_type
      raise ResponseInvalid, "Response has no content-type for '#{operation.name}'" unless content_type

      response_schema = response_definition.schema_for(content_type)
      unless response_schema
        message = "Response content type not found '#{content_type}' for '#{operation.name}'"
        raise ResponseContentTypeNotFoundError, message
      end
      validate_response_body(response_schema, body)
    end

    private

    def no_content?(response_definition)
      response_definition.status == 204 || !response_definition.content?
    end

    def response_for(operation, status)
      response = operation.response_for(status)
      return response if response

      message = "Response status code or default not found: #{status} for '#{operation.name}'"
      raise OpenapiFirst::ResponseCodeNotFoundError, message
    end

    def validate_status_only(operation, status)
      response_for(operation, status)
    end

    def validate_response_body(schema, response)
      full_body = +''
      response.each { |chunk| full_body << chunk }
      data = full_body.empty? ? {} : load_json(full_body)
      validation = schema.validate(data)
      raise ResponseBodyInvalidError, validation.message if validation.error?
    end

    def validate_response_headers(response_header_definitions, response_headers, openapi_version:)
      return unless response_header_definitions

      unpacked_headers = unpack_response_headers(response_header_definitions, response_headers)
      response_header_definitions.each do |name, definition|
        next if name == 'Content-Type'

        validate_response_header(name, definition, unpacked_headers, openapi_version:)
      end
    end

    def validate_response_header(name, definition, unpacked_headers, openapi_version:)
      unless unpacked_headers.key?(name)
        raise ResponseHeaderInvalidError, "Required response header '#{name}' is missing" if definition['required']

        return
      end

      return unless definition.key?('schema')

      validation = Schema.new(definition['schema'], openapi_version:)
      value = unpacked_headers[name]
      schema_validation = validation.validate(value)
      raise ResponseHeaderInvalidError, schema_validation.message if schema_validation.error?
    end

    def unpack_response_headers(response_header_definitions, response_headers)
      headers_as_parameters = response_header_definitions.map do |name, definition|
        definition.merge('name' => name, 'in' => 'header')
      end
      OpenapiParameters::Header.new(headers_as_parameters).unpack(response_headers)
    end

    def format_response_error(error)
      return "Write-only field appears in response: #{error['data_pointer']}" if error['type'] == 'writeOnly'

      JSONSchemer::Errors.pretty(error)
    end

    def load_json(string)
      MultiJson.load(string)
    rescue MultiJson::ParseError
      string
    end
  end
end
