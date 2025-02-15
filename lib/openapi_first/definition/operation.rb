# frozen_string_literal: true

require 'forwardable'
require 'set'
require_relative 'request_body'
require_relative 'response'
require_relative 'query_parameters'
require_relative 'header_parameters'
require_relative 'path_parameters'
require_relative 'cookie_parameters'
require_relative 'schema'

module OpenapiFirst
  class Operation
    extend Forwardable
    def_delegators :operation_object,
                   :[],
                   :dig

    WRITE_METHODS = Set.new(%w[post put patch delete]).freeze
    private_constant :WRITE_METHODS

    attr_reader :path, :method, :openapi_version

    def initialize(path, request_method, path_item_object, openapi_version:)
      @path = path
      @method = request_method
      @path_item_object = path_item_object
      @openapi_version = openapi_version
      @operation_object = @path_item_object[request_method]
    end

    def operation_id
      operation_object['operationId']
    end

    def read?
      !write?
    end

    def write?
      WRITE_METHODS.include?(method)
    end

    def request_body
      @request_body ||= RequestBody.new(operation_object['requestBody'], self) if operation_object['requestBody']
    end

    def response_for(status)
      response_object = operation_object.dig('responses', status.to_s) ||
                        operation_object.dig('responses', "#{status / 100}XX") ||
                        operation_object.dig('responses', "#{status / 100}xx") ||
                        operation_object.dig('responses', 'default')
      Response.new(status, response_object, self) if response_object
    end

    def name
      @name ||= "#{method.upcase} #{path} (#{operation_id})"
    end

    def query_parameters
      @query_parameters ||= build_parameters(all_parameters.filter { |p| p['in'] == 'query' }, QueryParameters)
    end

    def path_parameters
      @path_parameters ||= build_parameters(all_parameters.filter { |p| p['in'] == 'path' }, PathParameters)
    end

    IGNORED_HEADERS = Set['Content-Type', 'Accept', 'Authorization'].freeze
    private_constant :IGNORED_HEADERS

    def header_parameters
      @header_parameters ||= build_parameters(find_header_parameters, HeaderParameters)
    end

    def cookie_parameters
      @cookie_parameters ||= build_parameters(all_parameters.filter { |p| p['in'] == 'cookie' }, CookieParameters)
    end

    def all_parameters
      @all_parameters ||= begin
        parameters = @path_item_object['parameters']&.dup || []
        parameters_on_operation = operation_object['parameters']
        parameters.concat(parameters_on_operation) if parameters_on_operation
        parameters
      end
    end

    private

    attr_reader :operation_object

    def build_parameters(parameters, klass)
      klass.new(parameters, openapi_version:) if parameters.any?
    end

    def find_header_parameters
      all_parameters.filter do |p|
        p['in'] == 'header' && !IGNORED_HEADERS.include?(p['name'])
      end
    end
  end
end
