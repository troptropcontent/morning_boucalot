import { Controller } from "@hotwired/stimulus"
import Cropper from "cropperjs"

// Draws a crop box over the photo and mirrors it into the form as fractions
// of the image, so the saved crop doesn't depend on the size shown here.
//
// Straightening tilts the image under the crop box. The usable image is then
// the largest upright rectangle with the photo's proportions that fits inside
// the tilted one (PhotoEdits#straightened_area does the same on the server):
// the box is kept inside it, and its fractions are measured against it.
export default class extends Controller {
  static targets = ["image", "x", "y", "w", "h", "angle", "slider", "angleLabel", "ratio"]
  static values = { box: Array, angle: Number }

  connect() {
    this.cropper = new Cropper(this.imageTarget, {
      viewMode: 1,
      autoCropArea: 1,
      // Only the crop box moves; panning or zooming the image under it is
      // easy to trigger by accident on a phone.
      movable: false,
      zoomable: false,
      // Rotation only through the slider, see #straighten.
      rotatable: true,
      scalable: false,
      // The image is a variant that's already upright, and reading its EXIF
      // would need a cross-origin fetch once it redirects to S3.
      checkOrientation: false,
      checkCrossOrigin: false,
      ready: () => this.#restore(),
      crop: () => this.#keepInside()
    })
  }

  disconnect() {
    this.cropper?.destroy()
    this.cropper = null
  }

  straighten() {
    this.#rotateTo(Number(this.sliderTarget.value))
  }

  level() {
    this.sliderTarget.value = 0
    this.#rotateTo(0)
  }

  setRatio({ currentTarget }) {
    this.#applyRatio(currentTarget)
  }

  reset() {
    this.sliderTarget.value = 0
    this.#rotateTo(0)
    this.#applyRatio(this.#originalRatioButton)
  }

  // Opens in the photo's original ratio, unless the saved crop has other
  // proportions: locking the ratio would reshape it, so that opens in Free.
  #restore() {
    // Anything synced while Cropper was still building isn't a real box.
    this.fractions = null
    this.#rotateTo(this.angleValue)
    const saved = this.boxValue.length === 4
    const [x, y, w, h] = this.boxValue
    // Fractions of an area with the photo's proportions, so equal ones mean
    // the box has them too.
    const keepsRatio = !saved || Math.abs(w - h) < 0.002
    this.#applyRatio(keepsRatio ? this.#originalRatioButton : this.#freeRatioButton)
    if (saved) this.#placeBox(this.boxValue)
  }

  #applyRatio(button) {
    const param = button.dataset.photoCropRatioParam
    // The image is already turned upright, and straightening keeps its
    // proportions, so its natural size gives the original ratio.
    const { naturalWidth, naturalHeight } = this.cropper.getImageData()
    const ratio = param === "original" ? naturalWidth / naturalHeight : Number(param)

    this.cropper.setAspectRatio(ratio || NaN)
    this.#markActive(button)
    this.#fillArea()
  }

  get #originalRatioButton() {
    return this.ratioTargets.find((target) => target.dataset.photoCropRatioParam === "original")
  }

  get #freeRatioButton() {
    return this.ratioTargets.find((target) => Number(target.dataset.photoCropRatioParam) === 0)
  }

  // A new angle resizes the usable area; the box keeps its place and size
  // within it, so straightening never undoes the crop (and going back to the
  // previous angle gives the exact same box). Taken from the last sync rather
  // than re-measured, so sliding back and forth doesn't drift.
  #rotateTo(angle) {
    const box = this.fractions ?? [0, 0, 1, 1]
    this.angle = angle
    this.angleLabelTarget.textContent = `${angle.toFixed(1)}°`
    this.cropper.rotateTo(angle)
    this.#placeBox(box)
  }

  #fillArea() {
    this.#placeBox([0, 0, 1, 1])
  }

  // `box` is [x, y, w, h] as fractions of the usable area.
  #placeBox([x, y, w, h]) {
    const area = this.#area()
    this.cropper.setData({ x: area.x + x * area.width, y: area.y + y * area.height, width: w * area.width, height: h * area.height })
  }

  // Runs on every change of the box: pulls it back inside the usable area
  // (shrinking it if needed, keeping any locked ratio), then syncs the form.
  // Setting the data fires this again, so the guard stops the loop.
  #keepInside() {
    if (this.clamping) return

    const area = this.#area()
    let { x, y, width, height } = this.cropper.getData()
    const ratio = this.cropper.options.aspectRatio

    if (width > area.width) {
      if (ratio) height *= area.width / width
      width = area.width
    }
    if (height > area.height) {
      if (ratio) width *= area.height / height
      height = area.height
    }
    const clamped = {
      x: Math.min(Math.max(x, area.x), area.x + area.width - width),
      y: Math.min(Math.max(y, area.y), area.y + area.height - height),
      width,
      height
    }

    const tolerance = 0.5
    const data = this.cropper.getData()
    if (Object.keys(clamped).some((key) => Math.abs(clamped[key] - data[key]) > tolerance)) {
      this.clamping = true
      this.cropper.setData(clamped)
      this.clamping = false
    }
    this.#sync()
  }

  // In the image's natural pixels, relative to the tilted image's bounding
  // box, which is what Cropper's getData/setData use once rotated.
  #area() {
    const { naturalWidth: width, naturalHeight: height } = this.cropper.getImageData()
    const radians = Math.abs(this.angle || 0) * Math.PI / 180
    const cos = Math.cos(radians)
    const sin = Math.sin(radians)
    const canvasWidth = width * cos + height * sin
    const canvasHeight = width * sin + height * cos
    const scale = Math.min(width / canvasWidth, height / canvasHeight)

    return {
      x: (canvasWidth - width * scale) / 2,
      y: (canvasHeight - height * scale) / 2,
      width: width * scale,
      height: height * scale
    }
  }

  #sync() {
    const { x, y, width, height } = this.cropper.getData()
    const area = this.#area()

    this.fractions = [(x - area.x) / area.width, (y - area.y) / area.height, width / area.width, height / area.height]

    this.xTarget.value = this.fractions[0].toFixed(6)
    this.yTarget.value = this.fractions[1].toFixed(6)
    this.wTarget.value = this.fractions[2].toFixed(6)
    this.hTarget.value = this.fractions[3].toFixed(6)
    this.angleTarget.value = (this.angle || 0).toFixed(2)
  }

  #markActive(button) {
    this.ratioTargets.forEach((target) => {
      const active = target === button
      target.classList.toggle("btn-active", active)
      target.setAttribute("aria-pressed", active)
    })
  }
}
