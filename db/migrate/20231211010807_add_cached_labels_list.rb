class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string
    Conversation.reset_column_information
    # Initialize cache only if constant exists (handles gem version compatibility)
    ActsAsTaggableOn::Taggable::Cache.included(Conversation) if defined?(ActsAsTaggableOn::Taggable::Cache)
  end
end
