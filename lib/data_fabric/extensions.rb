require 'data_fabric/connection_proxy'

class ActiveRecord::ConnectionAdapters::ConnectionHandler
  def clear_active_connections_with_data_fabric!
    clear_active_connections_without_data_fabric!
    DataFabric::ConnectionProxy.shard_pools.each_value { |pool| pool.release_connection }
  end
  alias_method_chain :clear_active_connections!, :data_fabric
end

module DataFabric
  module Extensions

    def self.included(model)
      DataFabric.logger.info { "Loading data_fabric #{DataFabric::Version::STRING} with ActiveRecord #{ActiveRecord::VERSION::STRING}" }

      # Wire up ActiveRecord::Base
      model.extend ClassMethods
      ConnectionProxy.shard_pools = {}

      class << model
       alias_method :__original_ar_connection_pool, :connection_pool
      end

    end

    # Class methods injected into ActiveRecord::Base
    module ClassMethods

      def data_fabric(options)
        DataFabric.logger.info { "Creating data_fabric proxy for class #{name}" }
        connection_handler.connection_pools[name] = PoolProxy.new(ConnectionProxy.new(self, options))
      end

      def with_master(&block)
        connection_handler.connection_pools[name].connection.with_master(&block)
      end

      def with_current_db(&block)
        connection_handler.connection_pools[name].connection.with_current_db(&block)
      end

      def with_slave(&block)
        connection_handler.connection_pools[name].connection.with_slave(&block)
      end
    end
  end
end
