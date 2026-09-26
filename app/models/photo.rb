# The ten photos from the 2015 Christmas gift (amcritchie/grieg_mcritchie),
# in their original order. There is no database: this list IS the data.
#
# width/height are the pixel sizes of the files in app/assets/images/photos,
# so the browser reserves each photo's box before it loads. PhotoTest reads
# them back out of the JPEG headers, so a re-exported photo cannot drift.
Photo = Data.define(:number, :width, :height, :alt) do
  def self.all
    ALL
  end

  def filename
    "photos/greig#{number}.jpg"
  end

  def orientation
    width >= height ? "landscape" : "portrait"
  end
end

Photo::ALL = [
  Photo.new(number: 1, width: 639, height: 426,
    alt: "Singing into a microphone and playing a black electric guitar on a dark stage, a Marshall amp behind him"),
  Photo.new(number: 2, width: 576, height: 768,
    alt: "A curly-haired poodle in a plastic cone collar standing on a tiled entryway floor"),
  Photo.new(number: 3, width: 1024, height: 768,
    alt: "A family selfie at night, four faces crowded into the frame and smiling"),
  Photo.new(number: 4, width: 1024, height: 768,
    alt: "A guitar pedalboard of colourful effects pedals, including a wah pedal and a Memory Man delay"),
  Photo.new(number: 5, width: 576, height: 768,
    alt: "A graduate in a black cap and gown beside a woman reaching up to a flowering tree"),
  Photo.new(number: 6, width: 576, height: 768,
    alt: "Two runners holding up their medals under the inflatable Great Urban Race finish arch"),
  Photo.new(number: 7, width: 559, height: 768,
    alt: "Two young brothers lying on a bed, the older one in a Just Do It shirt cuddling the baby"),
  Photo.new(number: 8, width: 512, height: 768,
    alt: "A small boy in a white sweatshirt with a drawn-on moustache, holding a toy on a string"),
  Photo.new(number: 9, width: 2400, height: 1606,
    alt: "A smiling boy flexing both arms in front of a smooth sandstone rock wall"),
  Photo.new(number: 10, width: 2400, height: 1616,
    alt: "A boy wrapped in a pink towel on a patio while someone hides under a white towel behind him")
].freeze
