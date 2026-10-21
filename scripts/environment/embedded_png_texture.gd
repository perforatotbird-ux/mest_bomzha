@tool
extends ImageTexture
## Lossless embedded PNG texture; keeps binary artwork portable in text-only Git transports.
@export_multiline var png_base64: String = "":
	set(value):
		png_base64 = value
		if value.is_empty():
			return
		var image := Image.new()
		var error := image.load_png_from_buffer(Marshalls.base64_to_raw(value))
		if error == OK:
			set_image(image)
		else:
			push_error("Embedded PNG decode failed: %s" % error_string(error))
