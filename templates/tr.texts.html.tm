<html t:params="$tr">
<title>XXX</title>
<link rel=stylesheet href=/css/common.css>

<!-- XXX onbeforeunload -->

<header itemscope itemtype=data>
  <hgroup> 
    <h1><code itemprop=url><t:text value="$tr->url"></code></h1>
    <h2><code itemprop=branch><t:text value="$tr->branch"></code></h2>
    <h3><code itemprop=texts-path><t:text value="'/' . $tr->texts_dir"></code></h3>
  </hgroup>

  <link itemprop=data-url href=data.json>
</header>

<table id=texts>
  <t:my as=$lang_cell_count x="0+@{$tr->langs}">
  <thead>
    <tr>
      <t:for as=$lang x="$tr->langs">
        <th><t:text value=$lang>
      </t:for>
  <tbody>
    <template>
      <tr class=text-header>
        <th pl:colspan=$lang_cell_count>
          <code class=msgid></code>
          <code class=text-id></code>
      <tr class=text-body>
        <t:for as=$lang x="$tr->langs">
          <td pl:data-lang=$lang>
            <form data-action="i/{text_id}/" method=post onsubmit=" return saveLangCell (this) ">
              <input type=hidden name=lang pl:value=$lang>
              <!-- XXX hash -->
              <p><textarea name=body_o></textarea>
              <p><button type=submit>保存</button>
                <span class=status hidden><progress></progress> <span class=message></span></span>
            </form>
        </t:for>
    </template>
  <tfoot>
    <tr class=status hidden>
      <td pl:colspan=$lang_cell_count>
        <progress></progress> <span class=message></span>
    <tr>
      <td pl:colspan=$lang_cell_count>

<form action=add method=post onsubmit="
  var mainTable = document.getElementById ('texts');
  var mainTableStatus = mainTable.querySelector ('tfoot .status');
  mainTableStatus.hidden = false;
  mainTableStatus.querySelector ('.message').textContent = 'Adding...';

  var xhr = new XMLHttpRequest;
  xhr.open ('POST', this.action, true);
  var fd = new FormData (this);
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      if (xhr.status < 400) {
        var json = JSON.parse (xhr.responseText);
        addTexts (json.texts);
        mainTableStatus.hidden = true;
      } else { // XXX
      }
    }
  };
  xhr.send (fd);
  return false;
">
  <p>
    <label><strong>メッセージID</strong>: <input type=text name=msgid></label>
    <button type=submit>追加</button>
</form>


</table>

<script>
function addTexts (texts) {
        var mainTable = document.getElementById ('texts');
        var rowContainer = mainTable.querySelector ('tbody');
        var rowTemplate = rowContainer.querySelector ('template');
        for (var textId in texts) {
          var text = texts[textId];
          var fragment = document.createElement ('tbody');
          fragment.innerHTML = rowTemplate.innerHTML;

          fragment.querySelector ('.text-id').textContent = textId;
          if (text.msgid) {
            fragment.querySelector ('.msgid').textContent = text.msgid;
          }
          for (lang in text.langs) { // XXX escape
            var langCell = fragment.querySelector ('[data-lang="'+lang+'"]');
            if (langCell) {
              var langData = text.langs[lang];
              if (langData.body_o) {
                langCell.querySelector ('[name=body_o]').value = langData.body_o;
              }
            }
          }

          Array.prototype.forEach.call (fragment.querySelectorAll ('form[data-action]'), function (el) {
            el.action = el.getAttribute ('data-action').replace (/\{text_id\}/g, textId);
          });
          
          Array.prototype.slice.call (fragment.children).forEach (function (el) {
            rowContainer.appendChild (el);
          });
        }
} // addTexts

  var mainTable = document.getElementById ('texts');
  var mainTableStatus = mainTable.querySelector ('tfoot .status');
  mainTableStatus.hidden = false;
  mainTableStatus.querySelector ('.message').textContent = 'Loading...';

  var item = document.querySelector ('[itemtype=data]');
  var url = item.querySelector ('[itemprop=data-url]').href;
  var xhr = new XMLHttpRequest;
  xhr.open ('GET', url, true);
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      if (xhr.status < 400) {
        var json = JSON.parse (xhr.responseText);
        addTexts (json.texts);
        mainTableStatus.hidden = true;
      } else {
        // XXX
      }
    }
  };
  xhr.send (null);

function saveLangCell (form) {
  var formStatus = form.querySelector ('.status');
  formStatus.hidden = false;
  formStatus.querySelector ('.message').textContent = 'Saving...';

  var xhr = new XMLHttpRequest;
  xhr.open ('POST', form.action, true);
  var fd = new FormData (form);
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      if (xhr.status < 400) {
        formStatus.hidden = true;
      } else { // XXX
      }
    }
  };
  xhr.send (fd);
  return false;
} // saveLangCell
</script>
