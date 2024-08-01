# See https://graphql-ruby.org/dataloader/async_dataloader.html
# Should be possible to be removed with Rails 7.2
class RailsAwareAsyncDataloader < GraphQL::Dataloader::AsyncDataloader
  def get_fiber_variables # rubocop:disable Naming/AccessorMethodName
    vars = super
    # Collect the current connection config to pass on:
    vars[:connected_to] = {
      role: ActiveRecord::Base.current_role,
      shard: ActiveRecord::Base.current_shard,
      prevent_writes: ActiveRecord::Base.current_preventing_writes
    }
    vars
  end

  def set_fiber_variables(vars) # rubocop:disable Naming/AccessorMethodName
    connection_config = vars.delete(:connected_to)
    # Reset connection config from the parent fiber:
    ActiveRecord::Base.connecting_to(**connection_config)
    super
  end

  def cleanup_fiber
    super
    # Release the current connection
    ActiveRecord::Base.connection_pool.release_connection
  end
end
