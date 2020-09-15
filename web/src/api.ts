export async function dict_search(fetch, key, dic = '_tonghop') {
  const url = `/_dicts/search/${key}?dic=${dic}`
  const res = await fetch(url)
  const data = await res.json()

  return data
}

export async function dict_upsert(http, dic, key, val = '') {
  const url = `/_dicts/upsert/${dic}`
  const res = await http(url, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ key, val }),
  })

  const { _stt } = await res.json()
  return _stt
}

export async function load_chtext(fetch, bslug, seed, scid, mode = 0) {
  const url = `/_texts/${bslug}/${seed}/${scid}?mode=${mode}`

  try {
    const res = await fetch(url)
    const data = await res.json()

    if (res.status == 200) return data
    else this.error(res.status, data._msg)
  } catch (err) {
    this.error(500, err.message)
  }
}
