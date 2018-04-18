let React = require("./react.development");
let { ReactChildren, ReactElement } = React;
let child1 = ReactElement.createElement("image", { source: "img1" });
console.log(child1);
let child2 = ReactElement.createElement("image", { source: "img2" });
let child3 = ReactElement.createElement("image", { source: "img3" });
let instance = ReactElement.createElement(
  "div",
  { a: 1 },
  child1,
  child2,
  child3
);
let context = {};
ReactChildren.forEach(instance.props.children, console.log, context);
