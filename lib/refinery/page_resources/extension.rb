module Refinery
  module PageResources
    module Extension
      def has_many_page_resources
        has_many :page_resources, :as => :page, :order => 'position ASC'
        has_many :resources, :through => :page_resources, :order => 'position ASC'
        # accepts_nested_attributes_for MUST come before def resources_attributes=
        # this is because resources_attributes= overrides accepts_nested_attributes_for.

        accepts_nested_attributes_for :resources, :allow_destroy => false

        # need to do it this way because of the way accepts_nested_attributes_for
        # deletes an already defined resources_attributes
        module_eval do
          def resources_attributes=(data)
            ids_to_keep = data.map{|i, d| d['page_resource_id']}.compact

            page_resources_to_delete = if ids_to_keep.empty?
              self.page_resources
            else
              self.page_resources.where(
                Refinery::PageResource.arel_table[:id].not_in(ids_to_keep)
              )
            end

            page_resources_to_delete.destroy_all

            data.each do |i, resource_data|
              page_resource_id, resource_id, caption =
                resource_data.values_at('page_resource_id', 'id', 'caption')

              next if resource_id.blank?

              page_resource = if page_resource_id.present?
                self.page_resources.find(page_resource_id)
              else
                self.page_resources.build(:resource_id => resource_id)
              end

              page_resource.position = i
              page_resource.caption = caption if Refinery::PageResources.captions
              page_resource.save
            end
          end
        end

        include Refinery::PageResources::Extension::InstanceMethods

        attr_accessible :resources_attributes
      end

      module InstanceMethods

        def caption_for_resource_index(index)
          self.page_resources[index].try(:caption).presence || ""
        end

        def page_resource_id_for_resource_index(index)
          self.page_resources[index].try(:id)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:extend, Refinery::PageResources::Extension)
