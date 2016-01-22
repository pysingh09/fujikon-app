'use strict';

var React = require('react-native');
var { SMBLEManager } = require('NativeModules');
var Modal   = require('react-native-modalbox');

var ActivityOptions = require('./ActivityOptionListView');
var WorkoutOptions = require('./WorkoutOptionsListView');


var count = 0;
var listOptions = ['Activity','Workout'];
var activityName = "Running";
var workoutName = "Just Track Me";
var subTitle=[activityName,workoutName];
var deviceList = [];


var {
  Image,
  ListView,
  TouchableHighlight,
  StyleSheet,
  AsyncStorage,
  Text,
  View,
  NativeAppEventEmitter,
} = React;
  

var subscriptionBLE;

var ListViewSimpleExample = React.createClass({

  statics: {
    title: '<ListView> - Simple',
    description: 'Performant, scrollable list of data.'
  },

  getInitialState: function() {
    //console.log("Initialization..");
    
    var ds = new ListView.DataSource({rowHasChanged: (r1, r2) => r1 !== r2});
    return {
      // dataSource: new ListView.DataSource({
      //   rowHasChanged: (row1, row2) => row1 !== row2,
      // }),

       dataSource: ds.cloneWithRows(this.genRows()),
      // dataSourceForActivity: ds.cloneWithRows(['row1','row2','row3']),
      selectedActivity:"Running",
      connectionState:"Not Connected",
      isOpen: false,
      isDisabled: false,
      swipeToClose: true,
    };


  },

  genRows: function(){
    var deviceArray = [];
    for (var ii = 0; ii < deviceList.length; ii++) {
      console.log("Device name "+deviceList[ii]);
      var deviceName = deviceList[ii] ? deviceList[ii] : '';
      deviceArray.push(deviceName);
    } 
    console.log("Device array from list view :",deviceArray);
    return deviceArray;
  },

  refreshActivityData: function(data) {
  // console.log(this.state);
    this.setState({selectedActivity:data});

  },
  refreshWorkoutData: function(data) {
  // console.log(this.state);
  this.setState({selectedWorkout:data});
},


componentDidMount: function(){
  //console.log("Did Mounting...");

},

componentWillMount:function(){
  AsyncStorage.getItem("selectedActivity").then((value) => {
      //console.log("Async value "+value);
      activityName = value;
      this.setState({"selectedActivity": value});
    }).done();
  AsyncStorage.getItem("selectedWorkout").then((value) => {
      //console.log("Async value "+value);
      workoutName=value;
      this.setState({"selectedWorkout": value});
    }).done();
  //activityName = this.state.selectedActivity;
},

getOptions: function(){

    //activityName = this.state.selectedActivity;
    //console.log("Get Options called.."+activityName);
    return (

      <TouchableHighlight onPress={(this.onTabPressed.bind(this,count))} underlayColor="#EEEEEE">
      <View style={styles.container}>
      <View style={styles.rightContainer}>
      <Text style={styles.title}>{listOptions[count++]}</Text>
      <Text style={styles.year}>{this.state.intialValue}</Text>
      <View style={styles.separator} />
      </View>
      </View>
      
      </TouchableHighlight>

      );
    count++;
  },

  onStartPressed: function(){
    // var Workout = require('./Workout');
    // SMBLEManager.initParameters("180D","2A37");
    

    this.props.navigator.replace({
      component: Workout,
      componentConfig : {
        title : "My New Title"
      },
    });  

  },

  onConnectPressed: function(){
    var Workout = require('./Workout');
    SMBLEManager.initParameters("180D","2A37");
    subscriptionBLE = NativeAppEventEmitter.addListener("availableDeviceList", (data) => {
      console.log("Available device list from React : ",data.devices);
      deviceList = data.devices;
      this.openModal3();      

    });

    

    // this.props.navigator.replace({
    //   component: Workout,
    //   componentConfig : {
    //     title : "My New Title"
    //   },
    // });  

  },

  onTabPressed: function(rowID){
    console.log("Tab pressed...."+rowID);
    if(rowID==0)
    {
      this.props.navigator.push({
        component: ActivityOptions,
        backButtonTitle: 'Back',
        passProps : {obj: this},
        componentConfig : {
          title : "My New Title"
        },
      });
    }
    else
    {
      this.props.navigator.push({
        component: WorkoutOptions,
        backButtonTitle: 'Back',
        passProps : {obj: this}, 
        componentConfig : {
          title : "My New Title"
        },
      });
    }


  },

  openModal3: function(id) {
    this.refs.modal3.open();
  },

  renderRow: function(){
    return(
        <View style={styles.modalList}>
          <Text style={styles.year}>{deviceList}</Text>
        </View>
      );
  },

  renderFooter: function() {
    if (!this.hasMore() || !this.state.isLoadingTail) {
      return <View style={styles.scrollSpinner} />;
    }
    if (Platform.OS === 'ios') {
      return <ActivityIndicatorIOS style={styles.scrollSpinner} />;
    } else {
      return (
        <View  style={{alignItems: 'center'}}>
          <ProgressBarAndroid styleAttr="Large"/>
        </View>
      );
    }
  },

  render: function() {
    if(count!=0)
      count=0;
    return (
      <View style ={styles.screenContainer}>
          <View style={styles.titleContainer}>
            <Text style={styles.titleText}>Bluetooth Connection</Text>
          </View>

          <View style={styles.connectionContainer}>
            <Text style={styles.statusTitle}>Status : {this.state.connectionState} </Text>
          </View>

          <View style={styles.connectionButtonContainer}>
             <TouchableHighlight onPress={(this.onConnectPressed)} underlayColor="#EEEEEE" style={styles.connectButton}>  
             <Text style={styles.connectButtonText}>Connect</Text>
             </TouchableHighlight> 
          </View>

          <View style={styles.titleContainer}>
              <Text style={styles.titleText}>Choose From</Text>
          </View>
          <View style = {styles.container}>
              <TouchableHighlight onPress={(this.onTabPressed.bind(this,count))} underlayColor="#EEEEEE">
                <View style={styles.container}>
                  <View style={styles.rightContainer}>
                  <Text style={styles.title}>{listOptions[count++]}</Text>
                  <Text style={styles.year}>{this.state.selectedActivity}</Text>
                  </View>
                  <View style={styles.separator} />
                </View>
              </TouchableHighlight>
          <TouchableHighlight onPress={(this.onTabPressed.bind(this,count))} underlayColor="#EEEEEE">
            <View style={styles.container}>
              <View style={styles.rightContainer}>
              <Text style={styles.title}>{listOptions[count++]}</Text>
              <Text style={styles.year}>{this.state.selectedWorkout}</Text>
              <View style={styles.separator} />
              </View>
            </View>
          </TouchableHighlight>             
        </View>
        
      <View style={styles.bottomContainer}>
      <TouchableHighlight onPress={(this.onStartPressed)} underlayColor="#EEEEEE" style={styles.button}>
      <Text style={styles.buttonText}>Start</Text>
      </TouchableHighlight>
      </View>

      <Modal style={[styles.modal, styles.modal3]} position={"center"} ref={"modal3"}>
          <View style={styles.titleContainer}>
            <Text style={styles.titleText}>Available Devices :</Text>
          </View>
          <ListView
        ref="listview"
        // renderSeparator={this.renderSeparator}
        dataSource={this.state.dataSource}
        // renderFooter={this.renderFooter}
        renderRow={this.renderRow}
        // onEndReached={this.onEndReached}
        automaticallyAdjustContentInsets={false}
        keyboardDismissMode="on-drag"
        keyboardShouldPersistTaps={true}
        showsVerticalScrollIndicator={false}/>
        </Modal>
      </View>
      );

},

});

var styles = StyleSheet.create({
  listView: {
    paddingTop: 30,
        //backgroundColor: '#F5FCFF',
        height:200,
      },
      screenContainer:{
        paddingTop:50,
        flex:1,
      },
      container: {
        //flex: 1,
        //flexDirection: 'row',
        marginTop:10,
        alignItems: 'stretch',
        justifyContent: 'center',        //backgroundColor: '#F5FCFF',
      },
      rightContainer: {
        //flex: 1,
        height: 70,
        alignItems : 'center',
        justifyContent: 'center',
      },
      bottomContainer:{
        //flex:1,
        justifyContent: 'flex-end',
        marginBottom:100,
      },
      modalList:{
        justifyContent:'center',
      },
      title: {
        fontSize: 20,
        marginBottom: 6,
        textAlign: 'center',
      },
      year: {
        textAlign: 'center',
      },
      statusTitle: {
        fontSize: 15,
        marginBottom: 6,
        textAlign: 'center',
      },
      button: {
        height: 40,
        //flex: 1,
        backgroundColor: "#FCB130",
        borderColor: "#555555",
    //borderWidth: 1,
    borderRadius: 8,
    marginTop: 10,
    marginRight: 15,
    marginLeft: 15,
    justifyContent: "center",
  },
  titleContainer :{
    height:40,
    alignSelf:'stretch',
    alignItems:'flex-start',
    backgroundColor:'#F1F1F1',
    marginTop:10,
  },
  buttonText: {
    fontSize: 18,
    color: "#ffffff",
    alignSelf: "center"
  },
  separator: {
    height: 1,
    backgroundColor:"#7C7C7C",
    marginRight:50,
    marginLeft:50,
  },
  connectionContainer: {
        //flex: 1,
        //flexDirection: 'row',
        marginLeft:15,
        marginTop:10,
        alignItems: 'flex-start',
        //justifyContent: 'center',        //backgroundColor: '#F5FCFF',
      },
  connectButtonText: {
    fontSize: 15,
    color: "#ffffff",
    alignSelf: "center",

  },
  connectButton: {
        height: 34,
        //flex: 1,
        backgroundColor: "#FCB130",
        borderColor: "#555555",
    //borderWidth: 1,
    borderRadius: 8,
     marginRight: 15,
     marginBottom:15,
     marginLeft: 15,
    width:100,
    justifyContent: "center",
  },
  connectionButtonContainer:{
    //flex: 1,
    justifyContent:"flex-end",
    alignItems:"flex-end",
  },
  titleText:{
    fontSize:18,
    marginRight:15,
    // marginBottom:5,
    marginLeft: 15,
    marginTop:10,
  },
   modal: {
    justifyContent: 'center',
    alignItems: 'center'
  },
  modal3: {
    height: 300,
    width: 300,
  },

});
module.exports = ListViewSimpleExample;