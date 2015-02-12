<html t:params="$texts $langs">
<title>???</title>

<header itemscope itemtype=data>
<h1>Texts</h1>

  <link itemprop=data-url href=data.json>
</header>

<table id=texts>
  <thead>
    <tr>
      <t:for as=$lang x=$langs>
        <td><t:text value=$lang>
      </t:for>
  <tbody>
    <template>
      <tr>
        <th pl:colspan="0+@$langs">
          <code class=text-id></code>
          <code class=msgid></code>
      <tr>
        <t:for as=$lang x=$langs>
          <td pl:data-lang=$lang>
            <form data-action="i/{text_id}/" method=post>
              <input type=hidden name=lang pl:value=$lang>
              <!-- XXX hash -->
              <p><textarea name=body_o></textarea>
              <p><button type=submit>保存</button>
            </form>
        </t:for>
    </template>
</table>

<script>
  var item = document.querySelector ('[itemtype=data]');
  var url = item.querySelector ('[itemprop=data-url]').href;
  var xhr = new XMLHttpRequest;
  xhr.open ('GET', url, true);
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      if (xhr.status < 400) {
        var json = JSON.parse (xhr.responseText);
        var mainTable = document.getElementById ('texts');
        var rowContainer = mainTable.querySelector ('tbody');
        var rowTemplate = rowContainer.querySelector ('template');
        for (var textId in json.texts) {
          var text = json.texts[textId];
          var fragment = document.createElement ('tbody');
          fragment.innerHTML = rowTemplate.innerHTML;
console.log(fragment);

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
      } else {
        // XXX
      }
    }
  };
  xhr.send (null);
</script>

<form action=add method=post>
  <p><label><strong>メッセージID</strong>: <input type=text name=msgid></label>

  <p><input name=commit_message title=コミットメッセージ> <button type=submit>Add</button>
</form>

