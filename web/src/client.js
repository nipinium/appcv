import * as sapper from '@sapper/app'
import '@nipin/mould/css/premade.scss'
import '@nipin/mould/css/utilities.scss'

// import { fetch } from 'sapper'
// window.fetch = window.fetch || fetch

window._goto = sapper.goto

sapper.start({
  target: document.querySelector('#sapper'),
})