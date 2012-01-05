#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.


module Jobs
  class ProcessPhoto < Base
    @queue = :photos
    def self.perform(id)
      photo = Photo.find_by_id(id)
      return false  if photo.nil?

      unprocessed_image = photo.unprocessed_image
      return false if photo.processed? || unprocessed_image.path.try(:include?, ".gif")

      photo.processed_image.store!(unprocessed_image)

      photo.save or Rails.logger.info("ProcessPhoto job failed: #{photo.errors.inspect}")
    end
  end
end
