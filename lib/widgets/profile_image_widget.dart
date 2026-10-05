import 'dart:developer';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/assets_manager.dart';
import 'package:flutter_chess_app/widgets/avatar_selection_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final bool isEditable;
  final Function(File?)? onImageSelected;
  final Function(String?)? onAvatarSelected;
  final Color? backgroundColor;
  final IconData? placeholderIcon;
  final String? countryCode;
  final File? selectedImageFile;
  final String? selectedAvatar;

  const ProfileImageWidget({
    super.key,
    this.imageUrl,
    this.radius = 50,
    this.isEditable = false,
    this.onImageSelected,
    this.onAvatarSelected,
    this.backgroundColor,
    this.placeholderIcon = Icons.person,
    this.countryCode,
    this.selectedImageFile,
    this.selectedAvatar,
  });

  Future<void> _chooseAvatar(BuildContext context) async {
    final selectedAvatar = await AvatarSelectionDialog.show(context: context);

    if (selectedAvatar != null) {
      onAvatarSelected?.call(selectedAvatar);
      onImageSelected?.call(null);
    }
  }

  void _removeImage() {
    onImageSelected?.call(null);
    onAvatarSelected?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    Widget profileImage;

    // Priority: selected image > selected avatar > widget imageUrl > default
    if (selectedImageFile != null) {
      profileImage = CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(selectedImageFile!),
        backgroundColor: backgroundColor ?? Colors.grey[300],
      );
    } else if (selectedAvatar != null) {
      profileImage = CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(selectedAvatar!),
        backgroundColor: backgroundColor ?? Colors.grey[300],
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (imageUrl!.startsWith('assets')) {
        profileImage = CircleAvatar(
          radius: radius,
          backgroundImage: AssetImage(imageUrl!),
          backgroundColor: backgroundColor ?? Colors.grey[300],
        );
      } else {
        // Network image
        profileImage = CachedNetworkImage(
          imageUrl: imageUrl!,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: radius,
            backgroundImage: imageProvider,
            backgroundColor: backgroundColor ?? Colors.grey[300],
          ),
          placeholder: (context, url) => CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor ?? Colors.grey[300],
            child: Icon(placeholderIcon, size: radius),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: radius,
            backgroundImage: AssetImage(AssetsManager.userIcon),
            backgroundColor: backgroundColor ?? Colors.grey[300],
          ),
        );
      }
    } else {
      profileImage = CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(AssetsManager.userIcon),
        backgroundColor: backgroundColor ?? Colors.grey[300],
      );
    }

    return Stack(
      children: [
        profileImage,
        if (isEditable)
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: radius * 0.3,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: IconButton(
                icon: Icon(
                  Icons.camera_alt,
                  size: radius * 0.25,
                  color: Colors.white,
                ),
                onPressed: () => _showImageSourceDialog(context),
              ),
            ),
          ),
        if (countryCode != null && countryCode != '' && !isEditable)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.6,
              height: radius * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: CountryFlag.fromCountryCode(
                  countryCode!,
                  theme: ImageTheme(height: radius * 0.6, width: radius * 0.6),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_search_rounded),
                title: const Text('Choose Avatar'),
                onTap: () {
                  Navigator.pop(context);
                  _chooseAvatar(context);
                },
              ),
              if (imageUrl != null ||
                  selectedImageFile != null ||
                  selectedAvatar != null)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    await _performImagePicking(context, source);
    // final permissionService = PermissionService();
    // PermissionResult permissionResult;

    // // Request appropriate permission based on source
    // if (source == ImageSource.camera) {
    //   permissionResult = await permissionService.requestCameraPermission(
    //     context,
    //   );
    // } else {
    //   permissionResult = await permissionService.requestStoragePermission(
    //     context,
    //   );
    // }

    // // Handle permission result
    // if (permissionResult == PermissionResult.granted) {
    //   await _performImagePicking(context, source);
    // } else if (permissionResult == PermissionResult.permanentlyDenied) {
    //   if (context.mounted) {
    //     final permissionName = source == ImageSource.camera
    //         ? 'Camera'
    //         : 'Photos';
    //     await permissionService.handlePermanentlyDeniedPermission(
    //       context,
    //       permissionName,
    //     );
    //   }
    // } else {
    //   // Permission denied - show fallback message
    //   if (context.mounted) {
    //     final permissionName = source == ImageSource.camera
    //         ? 'camera'
    //         : 'photo library';
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text(
    //           'Permission to access $permissionName was denied. You can still choose from available avatars.',
    //         ),
    //         action: SnackBarAction(
    //           label: 'Choose Avatar',
    //           onPressed: () => _chooseAvatar(context),
    //         ),
    //       ),
    //     );
    //   }
    // }
  }

  Future<void> _performImagePicking(
    BuildContext context,
    ImageSource source,
  ) async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final imageFile = File(image.path);
        onImageSelected?.call(imageFile);
      }
    } catch (e) {
      log('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error selecting image. Please try again.'),
            action: SnackBarAction(
              label: 'Choose Avatar',
              onPressed: () => _chooseAvatar(context),
            ),
          ),
        );
      }
    }
  }
}
