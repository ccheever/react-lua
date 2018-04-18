x = "REACT_FRAGMENT_TYPE"
y = "REACT_FRAGMENT" + "_TYPE"
z = "REACT_PROVIDER_TYPE"

q = 0xead0
r = 0xead0
s = 0xeace
t = 0xeacd

d = {};

function cmpNum(n) {
  for (let i = 0; i < n; i++) {
    let yes = (q === r);
    let no = (s === t);
    d.yes = yes;
    d.no = no;
  }
}

function cmpStr(n) {
  for (let i = 0; i < n; i++) {
    let yes = (x == y);
    let no = (x == z);
    d.yes = yes;
    d.no = no;
  }
}

function compare(n) {
  let timeIt = (f) => {
    let start = Date.now();
    f(n);
    let end = Date.now();
    return end - start;
  }
  console.log(timeIt(cmpNum));
  console.log(timeIt(cmpStr));
}

if (require.main === module) {
  compare(100000000);
}
