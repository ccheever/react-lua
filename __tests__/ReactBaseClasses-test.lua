ReactBaseClasses = require "ReactBaseClasses"

do
  local Component = ReactBaseClasses.Component 
  local PureComponent = ReactBaseClasses.PureComponent

  pc = PureComponent({myProp="a value"})
  print(pc.isReactComponent)
  print(pc.isPureReactComponent)

  c = Component({myProp="some val"})
  print(c.isReactComponent)
  print(c.isPureReactComponent)

  print(c.props)
  print(c.props.myProp)
  print(c.context)
  print(c.refs)
  print(c.updater)
  
end