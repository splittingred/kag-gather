module KAG
  module API
    module Controller
      class Base
        @@class_key = ''
        @@primary_key = 'id'

        attr_accessor :params, :errors, :uri, :primary_key, :_config

        def initialize(uri,params)
          @uri = uri
          @params = params
          @errors = Hash.new
          @response = {
            :message => '',
            :object => {},
            :success => true
          }
        end

        ##
        # Returns the config file parsed into a SymbolTable
        #
        # @return [SymbolTable]
        #
        def self.config
          c = KAG::Config.instance
          if c
            c
          else
            SymbolTable.new
          end
        end

        def self.build_class_name(uri)
          ar = uri.split('/')
          class_name = []
          ar.each do |arr|
            class_name << arr.capitalize
          end
          class_name = class_name.join.to_s
          class_name
        end

        # route to the right controller
        def self.route(method,params)
          uri = params[:splat].first.to_s
          path = 'api/controllers/'+uri+'.rb'
          class_name = Base.build_class_name(uri)

          if path.to_s == 'api/controllers/favicon.ico.rb'
            return 404
          end
          unless Base.verify_authentication(params)
            return 401
          end

          puts "Routing to #{path}"
          if File.exists?('lib/'+path)
            require path
          else
            uri = uri+'/index'
            path = 'api/controllers/'+uri+'.rb'
            if File.exists?('lib/'+path)
              require path
              class_name = Base.build_class_name(uri)
            else
              puts "Could not find path at: "+path
              return 404
            end
          end

          result = 404
          params.delete('splat')
          params.delete('captures')
          params.delete('api_key')

          puts 'Parameters: '
          puts params.inspect
          cl = KAG::API::Controller.const_get(class_name)
          if cl
            c = cl.new(uri,params)
            if c
              puts "Sending to method: #{method.to_s}"
              result = c.send(method.to_sym).to_json
            else
              puts "Failed initializing new #{class_name}"
            end
          else
            puts "Class #{class_name} does not exist!"
          end
          result
        end

        def self.verify_authentication(params)
          true
        end

        def get
          if @params[@@primary_key]
            self.read(@params[@@primary_key])
          else
            self.list
          end
        end

        # GET if primary key is specified
        def read(id)
          if @@class_key != ''
            c = Object.const_get(@@class_key).find(id)
            if c
              self.success('',d.attributes)
            else
              self.failure('err_nf',c)
            end
          else
            self.failure('',@params)
          end
        end

        # GET if no primary key specified
        def list
          if @@class_key != ''
            c = Object.const_get(@@class_key).where(@params)
            if c
              self.success('',c)
            else
              self.failure('err_nf',c)
            end
          else
            self.failure('',@params)
          end
        end

        def post
          404
        end
        def put
          404
        end
        def delete
          404
        end



        def success(message = '',object = {})
          {:success => true,:object => object,:message => message}
        end

        def failure(message = '',object = {})
          rv = {:success => false,:object => object,:message => message}
          if @errors.length > 0
            rv[:errors] = @errors
          end
          rv
        end

        def collection(results = {},total = nil)
          total = results.count unless total
          {:results => results,:total => total}
        end

        def set_error(f,v)
          @errors[f.to_sym] = v
        end
        def set_errors(vs)
          vs.each do |k,v|
            self.set_error(k,v)
          end
        end

        def clear_error(f)
          @errors.delete(f.to_s)
        end

        def reset_errors
          @errors.clear
        end

        def check_required(required_fields)
          non_supplied_fields = {}
          supplied_fields = {}
          required_fields.each do |field_name|
            unless @params.keys.include?(field_name)
              non_supplied_fields[field_name] = "required"
            else
              supplied_fields[field_name] = @params[field_name]
            end
          end
          if non_supplied_fields.keys.count > 0
            non_supplied_fields
          else
            true
          end
        end
      end

      class GetOnly < Base
        def post
          404
        end
        def put
          404
        end
        def delete
          404
        end
      end

      class PostOnly < Base
        def get
          404
        end
        def put
          404
        end
        def delete
          404
        end
      end
    end
  end
end


