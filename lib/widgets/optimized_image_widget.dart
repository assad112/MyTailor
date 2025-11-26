import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// Widget محسن لتحميل الصور مع skeleton loading
class OptimizedImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showSkeleton;

  const OptimizedImageWidget({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.showSkeleton = true,
  });

  @override
  Widget build(BuildContext context) {
    // إذا لم تكن هناك صورة، اعرض placeholder
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        // تحسينات الأداء
        memCacheWidth: width != null && width!.isFinite ? width!.toInt() : null,
        memCacheHeight: height != null && height!.isFinite
            ? height!.toInt()
            : null,
        maxWidthDiskCache: 800,
        maxHeightDiskCache: 800,
        // Skeleton loading أثناء التحميل
        placeholder: showSkeleton
            ? (context, url) => _buildSkeletonLoading()
            : null,
        // Widget الخطأ
        errorWidget: (context, url, error) => _buildErrorWidget(),
        // تحسينات إضافية
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  /// بناء Skeleton Loading مع تأثير shimmer
  Widget _buildSkeletonLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width != null && width!.isFinite ? width! : 100.0,
        height: height != null && height!.isFinite ? height! : 100.0,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// بناء Placeholder عندما لا توجد صورة
  Widget _buildPlaceholder() {
    if (placeholder != null) return placeholder!;

    final safeWidth = width != null && width!.isFinite ? width! : 100.0;
    final safeHeight = height != null && height!.isFinite ? height! : 100.0;

    return Container(
      width: safeWidth,
      height: safeHeight,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Icon(
        Icons.image,
        color: Colors.grey[400],
        size: (safeWidth < safeHeight ? safeWidth * 0.4 : safeHeight * 0.4),
      ),
    );
  }

  /// بناء Widget الخطأ
  Widget _buildErrorWidget() {
    if (errorWidget != null) return errorWidget!;

    final safeWidth = width != null && width!.isFinite ? width! : 100.0;
    final safeHeight = height != null && height!.isFinite ? height! : 100.0;

    return Container(
      width: safeWidth,
      height: safeHeight,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!, width: 1),
      ),
      child: Icon(
        Icons.broken_image,
        color: Colors.red[400],
        size: (safeWidth < safeHeight ? safeWidth * 0.4 : safeHeight * 0.4),
      ),
    );
  }
}

/// Widget محسن للصور الصغيرة (مثل ألوان الخامات)
class OptimizedSmallImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color? fallbackColor;
  final BorderRadius? borderRadius;

  const OptimizedSmallImageWidget({
    super.key,
    this.imageUrl,
    this.size = 24,
    this.fallbackColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(5),
        child: OptimizedImageWidget(
          imageUrl: imageUrl,
          width: size,
          height: size,
          borderRadius: BorderRadius.circular(5),
          showSkeleton: false, // لا نحتاج skeleton للصور الصغيرة
          placeholder: Container(
            width: size,
            height: size,
            color: fallbackColor ?? Colors.grey[300],
          ),
          errorWidget: Container(
            width: size,
            height: size,
            color: fallbackColor ?? Colors.grey[300],
          ),
        ),
      ),
    );
  }
}

/// Widget محسن للصور الكبيرة (مثل صور الخامات الرئيسية)
class OptimizedLargeImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const OptimizedLargeImageWidget({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedImageWidget(
      imageUrl: imageUrl,
      width: width,
      height: height,
      borderRadius: borderRadius,
      showSkeleton: true, // نحتاج skeleton للصور الكبيرة
      placeholder: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, color: Colors.grey[400], size: 48),
            const SizedBox(height: 8),
            Text(
              'لا توجد صورة',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
