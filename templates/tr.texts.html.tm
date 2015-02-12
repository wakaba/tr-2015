<html t:params="$texts $langs">
<title>???</title>

<h1>Texts</h1>

<table>
  <thead>
    <tr>
      <th>ID</th>
      <t:for as=$lang x=$langs>
        <td><t:text value=$lang>
      </t:for>
  <tbody>
    <t:for as=$text_id x="[keys %$texts]">
      <t:my as=$common x="$texts->{$text_id}->{common}">
      <t:my as=$ls x="$texts->{$text_id}->{langs}">
      <tr>
        <th>
          <t:text value=$text_id>
          <t:text value="$common->get ('msgid') // ''">
        </th>
        <t:for as=$lang x=$langs>
          <td>
            <form pl:action="'i/' . $text_id . '/'" method=post>
              <input type=hidden name=lang pl:value=$lang>
              <!-- XXX hash -->
              <p><textarea name=body_o t:parse><t:text value="$ls->{$lang}->get ('body_o') // ''"></textarea>
              <p><button type=submit>保存</button>
            </form>
        </t:for>
    </t:for>
</table>

<form action=add method=post>
  <p><label><strong>メッセージID</strong>: <input type=text name=msgid></label>

  <p><label><strong>言語</strong>: <select name=lang><option value=ja>日本語<option value=en>英語</select></label>
  <p><label><strong>文字列</strong>: <textarea name=body_o></textarea></label>

  <p><input name=commit_message title=コミットメッセージ> <button type=submit>Add</button>
</form>

