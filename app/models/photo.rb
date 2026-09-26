# The ten photos from the 2015 Christmas gift (amcritchie/grieg_mcritchie),
# in their original order. There is no database: this list IS the data.
#
# width/height are the pixel sizes of the files in app/assets/images/photos,
# so the browser reserves each photo's box before it loads. PhotoTest reads
# them back out of the JPEG headers, so a re-exported photo cannot drift.
#
# A photo wider than a phone needs also carries smaller copies beside it
# (greig9-640w.jpg, greig9-1200w.jpg), one per VARIANT_WIDTHS entry narrower
# than the photo. The page lists them in srcset so a phone downloads the copy
# its screen can show instead of the 2400px original.
class Photo < Data.define(:number, :width, :height, :alt)
  VARIANT_WIDTHS = [ 640, 1200 ].freeze

  Variant = Data.define(:filename, :width, :height)

  def self.all
    ALL
  end

  def filename
    "photos/greig#{number}.jpg"
  end

  def variants
    VARIANT_WIDTHS.select { |w| w < width }.map do |w|
      Variant.new(filename: "photos/greig#{number}-#{w}w.jpg", width: w, height: (height * w / width.to_f).round)
    end
  end

  # image_tag's srcset: every smaller copy plus the original, by pixel width.
  # Nil when there is nothing smaller to offer.
  def srcset
    return if variants.empty?

    variants.to_h { |variant| [ variant.filename, "#{variant.width}w" ] }.merge(filename => "#{width}w")
  end

  def orientation
    width >= height ? "landscape" : "portrait"
  end

  ALL = [
    new(number: 1, width: 639, height: 426,
      alt: "A man singing into a microphone and playing a black electric guitar on a dark stage, a Marshall amp behind him"),
    new(number: 2, width: 576, height: 768,
      alt: "A curly-haired poodle in a plastic cone collar standing on a tiled entryway floor"),
    new(number: 3, width: 1024, height: 768,
      alt: "A family selfie at night, four faces crowded into the frame and smiling"),
    new(number: 4, width: 1024, height: 768,
      alt: "A guitar pedalboard of colorful effects pedals, including a wah pedal and a Memory Man delay"),
    new(number: 5, width: 576, height: 768,
      alt: "A graduate in a black cap and gown beside a woman reaching up to a flowering tree"),
    new(number: 6, width: 576, height: 768,
      alt: "Two runners holding up their medals under the inflatable Great Urban Race finish arch"),
    new(number: 7, width: 559, height: 768,
      alt: "Two young brothers lying on a bed, the older one in a Just Do It shirt cuddling the baby"),
    new(number: 8, width: 512, height: 768,
      alt: "A small boy in a white sweatshirt with a drawn-on mustache, holding a toy on a string"),
    new(number: 9, width: 2400, height: 1606,
      alt: "A smiling boy flexing both arms in front of a smooth sandstone rock wall"),
    new(number: 10, width: 2400, height: 1616,
      alt: "A boy holding a pink towel on a patio while someone hides under a white towel behind him")
  ].freeze
end
