import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location_pkg;
import 'package:geocoding/geocoding.dart';
import 'dart:developer' as developer;
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddressPoint {
  final String address;
  final LatLng location;
  final String id;

  AddressPoint({
    required this.address,
    required this.location,
    required this.id,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};
  final location_pkg.Location _location = location_pkg.Location();
  final List<AddressPoint> _addressPoints = [];
  final TextEditingController _addressController = TextEditingController();
  final PageController _pageController = PageController();
  LatLng _currentPosition = const LatLng(35.6812, 139.7671); // 默认东京坐标
  bool _serviceEnabled = false;
  location_pkg.PermissionStatus? _permissionGranted;
  location_pkg.LocationData? _locationData;
  bool _isLoading = true;
  bool _isSearching = false;
  int _currentAddressIndex = 0;
  Marker? _tempMarker;
  bool _isReverseGeocoding = false;
  bool _isReordering = false;
  Set<Polyline> _polylines = {};
  Map<String, String> _routeInfo = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() => _isLoading = true);
      
      // 检查位置服务是否启用
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          developer.log('位置服务未启用');
          _showError('请启用位置服务');
          return;
        }
      }

      // 检查位置权限
      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == location_pkg.PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != location_pkg.PermissionStatus.granted) {
          developer.log('位置权限未授予');
          _showError('需要位置权限才能获取当前位置');
          return;
        }
      }

      // 开始监听位置更新
      _location.onLocationChanged.listen((location_pkg.LocationData currentLocation) {
        if (mounted) {
          _updateLocation(currentLocation);
        }
      });

      // 获取当前位置
      await _getCurrentLocation();
    } catch (e, stack) {
      developer.log('初始化位置服务失败', error: e, stackTrace: stack);
      _showError('初始化位置服务失败');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      _locationData = await _location.getLocation();
      if (_locationData != null) {
        _updateLocation(_locationData!);
      }
    } catch (e, stack) {
      developer.log('获取位置失败', error: e, stackTrace: stack);
      _showError('获取位置失败');
    }
  }

  void _updateLocation(location_pkg.LocationData locationData) {
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
        
        // 更新当前位置标记
        _updateMarkers();

        // 只在初始化时移动到当前位置
        if (_locationData == null) {
          mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentPosition,
                zoom: 15.0,
              ),
            ),
          );
        }
      });
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      
      // 添加当前位置标记
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentPosition,
          infoWindow: const InfoWindow(title: '当前位置'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );

      // 添加所有地址点标记
      for (var i = 0; i < _addressPoints.length; i++) {
        final point = _addressPoints[i];
        _markers.add(
          Marker(
            markerId: MarkerId(point.id),
            position: point.location,
            infoWindow: InfoWindow(
              title: '${i + 1}. ${point.address}',
              snippet: '${point.location.latitude}, ${point.location.longitude}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              i == _currentAddressIndex ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
            ),
          ),
        );
      }

      // 添加临时标记（如果有）
      if (_tempMarker != null) {
        _markers.add(_tempMarker!);
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    try {
      setState(() {
        mapController = controller;
        if (_locationData != null) {
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentPosition,
                zoom: 15.0,
              ),
            ),
          );
        }
      });
    } catch (e, stack) {
      developer.log('地图控制器初始化失败', error: e, stackTrace: stack);
    }
  }

  void _addAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showError('请输入地址');
      return;
    }

    setState(() => _isSearching = true);
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final addressPoint = AddressPoint(
          address: address,
          location: LatLng(location.latitude, location.longitude),
          id: 'address_${_addressPoints.length}',
        );

        setState(() {
          _addressPoints.add(addressPoint);
          _currentAddressIndex = _addressPoints.length - 1;
          _updateMarkers();
          _addressController.clear();
        });

        // 更新地图视角以显示所有标记点
        _fitMapToBounds();
        
        // 滚动到新添加的地址
        _pageController.animateToPage(
          _currentAddressIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _showAddressErrorDialog(address, '未找到该地址');
      }
    } catch (e, stack) {
      developer.log('地址解析失败', error: e, stackTrace: stack);
      _showAddressErrorDialog(address, '地址解析失败');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _showAddressErrorDialog(String address, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('地址解析失败'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('地址：$address'),
            const SizedBox(height: 8),
            Text(
              '错误：$error',
              style: TextStyle(color: Colors.red[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('放弃'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _addAddress(); // 重试添加地址
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _fitMapToBounds() {
    if (_markers.isEmpty || mapController == null) return;

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (final marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        50.0, // padding
      ),
    );
  }

  void _removeAddress(AddressPoint point) {
    final index = _addressPoints.indexOf(point);
    setState(() {
      _addressPoints.remove(point);
      _currentAddressIndex = _addressPoints.isEmpty ? 0 : 
        index >= _addressPoints.length ? _addressPoints.length - 1 : index;
      _updateMarkers();
      if (_addressPoints.isNotEmpty) {
        _fitMapToBounds();
        _pageController.animateToPage(
          _currentAddressIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleMapLongPress(LatLng position) async {
    setState(() {
      _isReverseGeocoding = true;
      // 添加临时标记
      _tempMarker = Marker(
        markerId: const MarkerId('temp'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      );
      _updateMarkers();
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.postalCode,
          placemark.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        _showLocationDialog(position, address);
      }
    } catch (e, stack) {
      developer.log('反向地理编码失败', error: e, stackTrace: stack);
      _showLocationDialog(position, '无法获取地址');
    } finally {
      setState(() => _isReverseGeocoding = false);
    }
  }

  void _showLocationDialog(LatLng position, String address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('位置信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isReverseGeocoding)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text('地址：$address'),
              const SizedBox(height: 8),
              Text(
                '坐标：${position.latitude}, ${position.longitude}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _tempMarker = null;
                _updateMarkers();
              });
            },
            child: const Text('清除'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final addressPoint = AddressPoint(
                address: address,
                location: position,
                id: 'address_${_addressPoints.length}',
              );
              setState(() {
                _addressPoints.add(addressPoint);
                _currentAddressIndex = _addressPoints.length - 1;
                _tempMarker = null;
                _updateMarkers();
              });
              _pageController.animateToPage(
                _currentAddressIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: const Text('添加到列表'),
          ),
        ],
      ),
    );
  }

  void _reorderAddress(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final AddressPoint item = _addressPoints.removeAt(oldIndex);
      _addressPoints.insert(newIndex, item);
      _currentAddressIndex = newIndex;
      _updateMarkers();
    });
  }

  void _showReorderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sort),
                    const SizedBox(width: 16),
                    const Text(
                      '拖动排序',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('完成'),
                      onPressed: () {
                        _pageController.animateToPage(
                          _currentAddressIndex,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: scrollController,
                  itemCount: _addressPoints.length,
                  onReorder: _reorderAddress,
                  itemBuilder: (context, index) {
                    final point = _addressPoints[index];
                    return Material(
                      key: ValueKey(point.id),
                      color: Colors.transparent,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index == _currentAddressIndex
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          point.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${point.location.latitude}, ${point.location.longitude}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.drag_handle),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _planRoute() async {
    if (_addressPoints.isEmpty) {
      _showError('请先添加地址点');
      return;
    }

    setState(() {
      _isLoading = true;
      _polylines.clear();
      _routeInfo.clear();
    });

    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_ANDROID_API_KEY'];
      if (apiKey == null) {
        throw Exception('Google Maps API Key not found in environment variables');
      }

      // 构建途经点列表，包括起点和终点
      final List<Map<String, dynamic>> locations = [
        {
          'waypoint': {
            'location': {
              'latLng': {
                'latitude': _currentPosition.latitude,
                'longitude': _currentPosition.longitude
              }
            }
          }
        }
      ];

      // 添加所有地址点作为途经点
      for (final point in _addressPoints) {
        locations.add({
          'waypoint': {
            'location': {
              'latLng': {
                'latitude': point.location.latitude,
                'longitude': point.location.longitude
              }
            }
          }
        });
      }

      final requestBody = {
        'origin': locations.first,
        'destination': locations.last,
        'intermediates': locations.length > 2 
            ? locations.sublist(1, locations.length - 1) 
            : [],
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'computeAlternativeRoutes': false,
        'routeModifiers': {
          'avoidTolls': false,
          'avoidHighways': false,
        },
        'languageCode': 'zh-CN',
        'units': 'METRIC'
      };

      final url = Uri.parse(
        'https://routes.googleapis.com/directions/v2:computeRoutes'
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          // 解析路线点
          final points = _decodePolyline(route['polyline']['encodedPolyline']);
          
          // 计算总距离和时间
          final distanceMeters = route['distanceMeters'] as int;
          final durationSeconds = route['duration'].replaceAll('s', '');
          final duration = int.parse(durationSeconds);

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: Colors.blue,
                width: 5,
              ),
            );

            _routeInfo['总距离'] = '${(distanceMeters / 1000).toStringAsFixed(1)} 公里';
            _routeInfo['预计时间'] = '${(duration / 60).ceil()} 分钟';
          });

          _fitMapToBounds();
        } else {
          throw Exception('未找到可用路线');
        }
      } else {
        throw Exception('路线规划请求失败: ${response.statusCode}\n${response.body}');
      }
    } catch (e, stack) {
      developer.log('路径规划失败', error: e, stackTrace: stack);
      _showError('路径规划失败: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 15.0,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                  padding: const EdgeInsets.only(bottom: 180),
                  onLongPress: _handleMapLongPress,
                ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                Positioned(
                  bottom: 200,
                  left: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'fitBounds',
                        onPressed: _fitMapToBounds,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        child: const Icon(Icons.fit_screen),
                      ),
                      const SizedBox(height: 16),
                      FloatingActionButton(
                        heroTag: 'planRoute',
                        onPressed: _planRoute,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        child: const Icon(Icons.route),
                      ),
                    ],
                  ),
                ),
                if (_routeInfo.isNotEmpty)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _routeInfo.entries.map((entry) => 
                            Text('${entry.key}: ${entry.value}')
                          ).toList(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            hintText: '输入地址',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onSubmitted: (_) => _addAddress(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSearching ? null : _addAddress,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('添加'),
                      ),
                    ],
                  ),
                ),
                if (_addressPoints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '已添加地址 (${_addressPoints.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.sort, size: 14),
                                onPressed: _showReorderDialog,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                tooltip: '拖动排序',
                              ),
                              const Icon(Icons.swipe, size: 14),
                              const SizedBox(width: 2),
                              const Text(
                                '左右滑动切换',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _addressPoints.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentAddressIndex = index;
                                _updateMarkers();
                                mapController?.animateCamera(
                                  CameraUpdate.newLatLng(_addressPoints[index].location),
                                );
                              });
                            },
                            itemBuilder: (context, index) {
                              final point = _addressPoints[index];
                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                child: GestureDetector(
                                  onLongPressStart: (details) {
                                    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                                    showMenu(
                                      context: context,
                                      position: RelativeRect.fromRect(
                                        details.globalPosition & const Size(1, 1),
                                        Offset.zero & overlay.size,
                                      ),
                                      items: [
                                        PopupMenuItem(
                                          enabled: false,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '完整地址信息',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                point.address,
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${point.location.latitude}, ${point.location.longitude}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: index == _currentAddressIndex
                                                  ? Theme.of(context).primaryColor
                                                  : Colors.grey,
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    point.address,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${point.location.latitude}, ${point.location.longitude}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              onPressed: () => _removeAddress(point),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
} 