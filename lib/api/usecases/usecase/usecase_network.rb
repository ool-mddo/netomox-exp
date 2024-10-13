# frozen_string_literal: true

require 'grape'
require_relative 'network/usecase_data_by_file'
require_relative 'network/usecase_snapshot'

module NetomoxExp
  module ApiRoute
    # namespace /network
    class UsecaseNetwork < Grape::API
      resource ':network' do
        mount ApiRoute::UsecaseDataByFile
        mount ApiRoute::UsecaseSnapshot
      end
    end
  end
end
