require 'sinatra/base'
require 'thread'
require 'yard'

module Solargraph
  class Server < Sinatra::Base

    set :port, 7657

    @@api_hash = {}
    @@semaphore = Mutex.new

    post '/prepare' do
      prepare_workspace params['directory']
    end

    post '/suggest' do
      content_type :json
      begin
        sugg = []
        workspace = params['workspace'] || CodeMap.find_workspace(params['filename'])
        Server.prepare_workspace workspace unless @@api_hash.has_key?(workspace)
        @@semaphore.synchronize {
          code_map = CodeMap.new(code: params['text'], filename: params['filename'], api_map: @@api_hash[workspace])
          offset = code_map.get_offset(params['line'].to_i, params['column'].to_i)
          sugg = code_map.suggest_at(offset, with_snippets: true, filtered: true)
        }
        { "status" => "ok", "suggestions" => sugg }.to_json
      rescue Exception => e
        STDERR.puts e
        STDERR.puts e.backtrace.join("\n")
        { "status" => "err", "message" => e.message + "\n" + e.backtrace.join("\n") }.to_json
      end
    end

    get '/search' do
      workspace = params['workspace']
      api_map = @@api_hash[workspace]
      required = []
      unless api_map.nil?
        required.concat api_map.required
      end
      yard = YardMap.new(required: required, workspace: workspace)
      @results = yard.search(params['query'])
      erb :search
    end

    get '/document' do
      workspace = params['workspace']
      api_map = @@api_hash[workspace]
      required = []
      unless api_map.nil?
        required.concat api_map.required
      end
      yard = YardMap.new(required: required, workspace: workspace)
      @objects = yard.document(params['query'])
      erb :document
    end

    def htmlify object
      h = Helpers.new
      h.object = object
      h.htmlify object.docstring.all, :rdoc
    end

    class << self
      def run!
        constant_updates
        super
      end

      def prepare_workspace directory
        api_map = Solargraph::ApiMap.new(directory)
        @@semaphore.synchronize {
          @@api_hash[directory] = api_map
        }
      end

      def constant_updates
        Thread.new {
          loop do
            @@api_hash.keys.each { |k|
              update = Solargraph::ApiMap.new(k)
              @@semaphore.synchronize {
                @@api_hash[k] = update
              }
            }
            sleep 10
          end
        }
      end
    end

    class Helpers
      attr_accessor :object
      attr_accessor :serializer
      include YARD::Templates::Helpers::HtmlHelper
      def options
        @options ||= YARD::Templates::TemplateOptions.new
      end
      def linkify *args
        args.join(', ')
      end
    end
  end
end
