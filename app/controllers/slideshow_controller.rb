class SlideshowController < ApplicationController
  def index
    @photos = Photo.all
  end
end
