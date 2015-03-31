<html t:params="$tr $tr_config $app">
<title>License - Text set configuration - XXX</title>
<link rel=stylesheet href=/css/common.css>
<body onbeforeunload=" if (document.trModified) return document.body.getAttribute ('data-beforeunload') " data-beforeunload="他のページへ移動します">

<t:include path=_header.html.tm />

<section>

  <header class=textset itemscope itemtype=data>
    <hgroup> 
      <h1 title=Repository><a href="../../" rel="up up up"><code itemprop=url><t:text value="$tr->url"></code></a></h1>
      <h2 title=Branch><a href="../" rel="up up"><code itemprop=branch><t:text value="$tr->branch"></code></a></h2>
      <h3 title=Path><a href="./" rel=up><code itemprop=texts-path><t:text value="'/' . $tr->texts_dir"></code></a></h3>
    </hgroup>
  </header>

  <section class=config>
    <header>
      <h1>ライセンス設定</h1>
    </header>

  <!-- XXX
  <meta itemprop=license pl:content="$tr_config->get ('license') // ''">
  <meta itemprop=license-holders pl:content="$tr_config->get ('license_holders') // ''">
  <meta itemprop=additional-license-terms pl:content="$tr_config->get ('additional_license_terms') // ''">
  -->

    <form action="license.ndjson" method=post>
      <table class=config>
        <tbody>
          <tr>
            <th><label for=config-license-license>ライセンス
            <td>
              <select name=license id=config-license-license required>
                <option value>ライセンスを選択
                <option value=CC0>CC0
                <option value=Public-Domain>Public Domain
                <option value=MIT>MIT ライセンス
                <option value=BSDModified>修正 BSD ライセンス
                <option value=Apache2>Apache License 2.0
                <option value=GPL2+>GPL2 以降
                <option value=GPL3+>GPL3 以降
                <option value=CC-BY-SA4>CC BY-SA 4.0
                <option value=Perl>Perl と同じ
                <option value=proprietary>独占的ライセンス
              </select>
          <tr>
            <th><label for=config-license-license_holders>ライセンス保有者</label>
            <td><input name=license_holders id=config-license-license_holders>
          <tr>
            <th><label for=config-license-additional_license_terms>追加のライセンス条項</label>
            <td><textarea name=additional_license_terms id=config-license-additional_license_terms></textarea>
      </table>

      <p class=buttons><button type=button class=save>保存して閉じる</button>
    </form>
    <p class=status hidden><progress></progress> <span class=message></span>
  <script>
    function toggleLicenseConfig (status) {
      var licensePanel = document.querySelector ('#config-license');
      if (status) {
        var item = document.querySelector ('[itemtype=data]');
        var form = licensePanel.querySelector ('form');
        form.elements.license.value = item.querySelector ('meta[itemprop=license]').content;
        form.elements['license_holders'].value = item.querySelector ('meta[itemprop=license-holders]').content;
        form.elements['additional_license_terms'].value = item.querySelector ('meta[itemprop=additional-license-terms]').content;
        licensePanel.hidden = false;
      } else {
        licensePanel.hidden = true;
      }
    } // toggleLicenseConfig

    (function () {
      var licensePanel = document.querySelector ('#config-license');
      licensePanel.trSync = function () {
        toggleLicenseConfig (false);
        history.replaceState (null, null, '#');
        var item = document.querySelector ('[itemtype=data]');
        var form = licensePanel.querySelector ('form');
        item.querySelector ('meta[itemprop=license]').content = form.elements.license.value;
        item.querySelector ('meta[itemprop=license-holders]').content = form.elements['license_holders'].value;
        item.querySelector ('meta[itemprop=additional-license-terms]').content = form.elements['additional_license_terms'].value;
      };
      licensePanel.querySelector ('button.save').onclick = function () {
        saveArea (licensePanel);
      };
      licensePanel.querySelector ('button.close').onclick = function () {
        toggleLicenseConfig (false);
        history.replaceState (null, null, '#');
      };

      var f = decodeURIComponent (location.hash.replace (/^#/, ''));
      if (f === 'config-license') {
        toggleLicenseConfig (true);
      }
    }) ();
  </script>

  </section>
</section>

<t:include path=_footer.html.tm />
