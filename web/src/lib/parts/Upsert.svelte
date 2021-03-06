<script context="module">
  import { writable } from 'svelte/store'
  import { tag_label } from '$lib/pos_tag.js'
  import { titleize } from '$utils/text_utils.js'
  import { dict_upsert, dict_search } from '$api/dictdb_api.js'

  export const tab = writable(0)
  export const state = writable(0)
  export const input = writable(['', 0, 1])

  export function activate(inp, _tab = 0, _state = 1) {
    tab.set(_tab)

    if (typeof inp == 'string') inp = [inp, 0, inp.length]
    input.set(inp)

    state.set(_state)
  }

  export function deactivate() {
    state.set(0)
  }

  const tab_kbds = ['x', 'c', 'v']
</script>

<script>
  import { session } from '$app/stores'
  import VpTerm from '$lib/vp_term.js'

  import Postag from '$parts/Postag.svelte'
  import SIcon from '$atoms/SIcon.svelte'
  import Input from './Upsert/Input.svelte'
  import Emend from './Upsert/Emend.svelte'
  import Vhint from './Upsert/Vhint.svelte'
  import Vutil from './Upsert/Vutil.svelte'
  import Vrank from './Upsert/Vrank.svelte'
  import Privi from './Upsert/Privi.svelte'
  import Links from './Upsert/Links.svelte'

  export let dname = 'combine'
  export let label = 'Tổng hợp'

  export let _dirty = false

  $: labels = [label, 'Thông dụng', 'Hán Việt']
  $: dnames = [dname, 'regular', 'hanviet']

  let trans = []
  let hints = []
  let terms = []

  $: term = get_term(terms, $tab)

  function get_term(terms, tab) {
    return terms[tab] || new VpTerm({ key }, tab + 1, $session.privi)
  }

  let key = ''
  $: if (key) init_search(key, dname)

  let value_field
  $: if (term) focus_on_value()

  function focus_on_value() {
    value_field && value_field.focus()
  }

  async function init_search(input, dname) {
    const [err, data] = await dict_search(fetch, input, dname)
    if (err) return

    trans = data.trans
    hints = [trans.hanviet, ...data.hints]
    terms = data.infos.map((x, i) => new VpTerm(x, i + 2, $session.privi))

    // set some default values if non present

    terms[0].fix_ptag(terms[1].ptag || terms[1].val ? '' : 'nr')
    terms[1].fix_ptag(terms[0]._raw.ptag)

    const first_hint = data.hints[0] || ''
    terms[0].fix_val(terms[1].val || first_hint || titleize(trans.hanviet, 9))
    terms[1].fix_val(terms[0].old_val || first_hint || trans.hanviet)
    terms[2].fix_val(first_hint.toLowerCase() || trans.hanviet)
  }

  async function submit_val() {
    const [err] = await dict_upsert(fetch, dnames[$tab], term.result)
    _dirty = !err
    deactivate()
  }
</script>

<div class="wrap" on:click={deactivate}>
  <div id="upsert" class="main" on:click|stopPropagation={focus_on_value}>
    <header class="head">
      <a href="/dicts/{dname}" class="m-button _text" target="_blank">
        <SIcon name="box" />
      </a>

      <Input phrase={$input} pinyin={trans.binh_am} bind:output={key} />

      <button
        type="button"
        class="m-button _text"
        data-kbd="esc"
        on:click={deactivate}>
        <SIcon name="x" />
      </button>
    </header>

    <section class="tabs">
      {#each labels as label, idx}
        <button
          class="-tab"
          class:_active={idx == $tab}
          class:_edited={terms[idx]?.old_val}
          data-kbd={tab_kbds[idx]}
          on:click={() => tab.set(idx)}>
          <span>{label}</span>
        </button>
      {/each}
    </section>

    <section class="body">
      <Emend {term} />

      <div class="field">
        <Vhint {hints} bind:term />

        <div class="value" class:_fresh={!term.old_val}>
          <input
            type="text"
            class="-input"
            bind:this={value_field}
            bind:value={term.val}
            autocomplete="off"
            autocapitalize={$tab < 1 ? 'words' : 'off'} />

          {#if $tab < 2}
            <button class="postag" data-kbd="p" on:click={() => state.set(2)}>
              {tag_label(term.ptag) || 'Chưa phân loại'}
            </button>
          {/if}
        </div>

        <Vutil bind:term />
      </div>

      <div class="vfoot">
        <Vrank bind:rank={term.rank} />

        <Privi
          {term}
          p_min={$tab + 1}
          p_max={$session.privi}
          on:click={() => submit_val($tab)} />
      </div>
    </section>

    <Links {key} />
  </div>
</div>

{#if $state > 1}
  <Postag bind:ptag={term.ptag} bind:state={$state} />
{/if}

<style lang="scss">
  $gutter: 0.75rem;

  .wrap {
    @include flex($center: both);
    position: fixed;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0;
    z-index: 9999;
    background: rgba(#000, 0.75);
  }

  .main {
    width: rem(30);
    min-width: 320px;
    max-width: 100%;
    @include bgcolor(tert);
    @include bdradi();
    @include shadow(3);
  }

  .head {
    display: flex;
    padding: 0.5rem 0.25rem;
    overflow: hidden;

    > .m-button {
      @include fgcolor(neutral, 5);
      background: none;
      --linesd: none;

      &:hover {
        @include fgcolor(primary, 5);
      }
    }
  }

  $tab-height: 2rem;

  .tabs {
    height: $tab-height;
    padding: 0 0.75rem;

    @include flex();
    @include border(--bd-main, $sides: bottom);
    @include ftsize(md);
    // prettier-ignore
  }

  .-tab {
    // text-transform: capitalize;
    font-weight: 500;
    padding: 0 0.75rem;
    background-color: transparent;

    height: $tab-height;
    line-height: $tab-height;
    flex-shrink: 0;

    margin-right: 0.5rem;

    @include bdradi($sides: top);
    @include fgcolor(tert);
    @include border(--bd-main);

    border-bottom: none;

    &:first-child {
      max-width: 38%;
      flex-shrink: 1;
    }

    &._edited {
      @include fgcolor(main);
    }

    &:hover {
      @include bgcolor(secd);
    }

    &._active {
      @include bgcolor(secd);
      @include fgcolor(primary, 5);
      @include bdcolor(primary, 6);
    }

    &:last-child {
      margin-left: auto;
      margin-right: 0;
    }

    > span {
      display: block;
      @include clamp($width: 100%);
    }
  }

  .body {
    @include bgcolor(bg-secd);
    padding: 0 0.75rem 0.75rem;
  }

  .field {
    position: relative;
    @include bdradi;

    @include linesd(--bd-main);
    @include bgcolor(main);

    &:focus-within {
      // @include linesd(primary, 4, $ndef: false);
      @include bgcolor(secd);
    }
  }

  .value {
    display: flex;
    $h-outer: 3rem;
    $h-inner: 1.75rem;

    height: $h-outer;
    padding: math.div($h-outer - $h-inner, 2);

    @include linesd(--bd-main);

    &:focus-within {
      @include linesd(primary, 4, $ndef: false);
    }

    > * {
      height: $h-inner;
      // line-height: 1.75rem;
    }

    &._fresh > * {
      font-style: italic;
    }

    > .-input {
      flex: 1;
      min-width: 1rem;
      outline: 0;
      border: 0;
      background: transparent;
      @include fgcolor(main);
      @include ftsize(lg);
    }
  }

  .postag {
    white-space: nowrap;
    padding: 0 0.5rem;
    margin-left: 0.5rem;
    background: transparent;
    border-radius: 0.75rem;
    font-weight: 500;

    @include ftsize(sm);

    @include fgcolor(tert);
    @include linesd(--bd-main);

    &:hover {
      @include fgcolor(primary, 5);
    }
  }

  .vfoot {
    display: flex;
    margin-top: 0.75rem;
    justify-content: right;
  }
</style>
