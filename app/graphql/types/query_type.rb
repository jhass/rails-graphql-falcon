# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, null: true], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ID], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # TODO: remove me
    field :test_field, String, null: false,
      description: "An example field added by the generator"
    def test_field
      "Hello World!"
    end

    field :random_number_one, Integer, null: false, description: "Fetches a random number." do
      argument :limit, Integer, required: true, description: "The maximum value of the random number."
    end
    def random_number_one(limit:)
      dataloader.with(Sources::RandomNumber).load(limit)
    end

    field :random_number_two, Integer, null: false, description: "Fetches a random number." do
      argument :limit, Integer, required: true, description: "The maximum value of the random number."
    end
    def random_number_two(limit:)
      dataloader.with(Sources::RandomNumber).load(limit)
    end
  end
end
