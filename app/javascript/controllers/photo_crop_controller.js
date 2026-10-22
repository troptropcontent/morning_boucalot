import { Controller } from "@hotwired/stimulus"
import Cropper from "cropperjs"

// Draws a crop box over the photo and mirrors it into the form as fractions
// of the image, so the saved crop doesn't depend on the size shown here.
export default class extends Controller {
  static targets = ["image", "x", "y", "w", "h", "ratio"]
  static values = { box: Array }

  connect() {
    this.cropper = new Cropper(this.imageTarget, {
      viewMode: 1,
      autoCropArea: 1,
      // Only the crop box moves; panning or zooming the image under it is
      // easy to trigger by accident on a phone.
      movable: false,
      zoomable: false,
      rotatable: false,
      scalable: false,
      // The image is a variant that's already upright, and reading its EXIF
      // would need a cross-origin fetch once it redirects to S3.
      checkOrientation: false,
      checkCrossOrigin: false,
      ready: () => this.#restoreBox(),
      crop: () => this.#sync()
    })
  }

  disconnect() {
    this.cropper?.destroy()
    this.cropper = null
  }

  setRatio({ currentTarget, params: { ratio } }) {
    this.cropper.setAspectRatio(ratio || NaN)
    this.#markActive(currentTarget)
  }

  reset() {
    this.cropper.setAspectRatio(NaN)
    this.cropper.reset()
    this.#markActive(this.ratioTargets[0])
  }

  #restoreBox() {
    if (this.boxValue.length !== 4) return

    const { naturalWidth, naturalHeight } = this.cropper.getImageData()
    const [x, y, w, h] = this.boxValue
    this.cropper.setData({ x: x * naturalWidth, y: y * naturalHeight, width: w * naturalWidth, height: h * naturalHeight })
  }

  #sync() {
    const { x, y, width, height } = this.cropper.getData()
    const { naturalWidth, naturalHeight } = this.cropper.getImageData()

    this.xTarget.value = (x / naturalWidth).toFixed(6)
    this.yTarget.value = (y / naturalHeight).toFixed(6)
    this.wTarget.value = (width / naturalWidth).toFixed(6)
    this.hTarget.value = (height / naturalHeight).toFixed(6)
  }

  #markActive(button) {
    this.ratioTargets.forEach((target) => {
      const active = target === button
      target.classList.toggle("btn-active", active)
      target.setAttribute("aria-pressed", active)
    })
  }
}
