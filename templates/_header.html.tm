<header class=site>
<h1><a href="/" rel=index>TR</a></h1>

<nav>
  <div class=account>
    <button type=button class=account-menu-button onclick="
      var menu = parentNode.querySelector ('menu');
      menu.hidden = !menu.hidden;
    ">アカウント</button>
    <menu hidden class=contextmenu>
      <p><a href=/tr>リポジトリー一覧</a>
      <hr>
      <form action=/account/login method=post class=login>
        <input type=hidden name=server value=github>
        <button type=submit>GitHub アカウントでログイン</button>
      </form>
      <form action=/account/login method=post class=login>
        <input type=hidden name=server value=hatena>
        <button type=submit>はてなIDでログイン</button>
      </form>
    </menu>
    <script>
      var xhr = new XMLHttpRequest;
      xhr.open ('GET', '/account/info.json', true);
      xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
          if (xhr.status === 200) {
            var json = JSON.parse (xhr.responseText);
            if (json.name) {
              var account = document.querySelector ('header.site .account');
              var button = account.querySelector ('.account-menu-button');
              button.textContent = json.name;
              account.classList.add ('has-account');
            }
          } else {
            // XXX
          }
        }
      };
      xhr.send (null);
    </script>
  </div>

  <a href="/help">Documentation</a>
</nav>
</header>
