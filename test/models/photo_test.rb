require "test_helper"

class PhotoTest < ActiveSupport::TestCase
  PHOTO_DIR = Rails.root.join("app/assets/images")

  test "there are ten photos numbered one to ten in order" do
    assert_equal (1..10).to_a, Photo.all.map(&:number)
  end

  test "every photo file exists" do
    Photo.all.each do |photo|
      assert PHOTO_DIR.join(photo.filename).file?, "missing #{photo.filename}"
    end
  end

  test "every photo has its own descriptive alt text" do
    alts = Photo.all.map(&:alt)
    alts.each { |alt| assert_operator alt.strip.length, :>=, 20, "alt too thin: #{alt.inspect}" }
    assert_equal alts.size, alts.uniq.size, "alt text repeats"
  end

  test "recorded width and height match the JPEG on disk" do
    Photo.all.each do |photo|
      actual = jpeg_size(PHOTO_DIR.join(photo.filename))
      assert_equal [ photo.width, photo.height ], actual, "#{photo.filename} dimensions drifted"
    end
  end

  test "no photo is heavier than half a megabyte" do
    Photo.all.each do |photo|
      size = PHOTO_DIR.join(photo.filename).size
      assert_operator size, :<=, 512 * 1024, "#{photo.filename} is #{size} bytes; recompress it"
    end
  end

  test "orientation follows the aspect ratio" do
    assert_equal "landscape", Photo.all.first.orientation
    assert_equal "portrait", Photo.all.second.orientation
  end

  private

  # Width and height from the first start-of-frame marker (SOF0..SOF15,
  # excluding DHT, JPG and DAC), the same header the browser reads.
  def jpeg_size(path)
    File.open(path, "rb") do |io|
      raise "#{path} is not a JPEG" unless io.read(2) == "\xFF\xD8".b

      loop do
        marker = io.read(2).bytes
        raise "#{path}: bad marker" unless marker[0] == 0xFF
        length = io.read(2).unpack1("n")
        if (0xC0..0xCF).cover?(marker[1]) && ![ 0xC4, 0xC8, 0xCC ].include?(marker[1])
          _precision, height, width = io.read(5).unpack("Cnn")
          return [ width, height ]
        end
        io.seek(length - 2, IO::SEEK_CUR)
      end
    end
  end
end
