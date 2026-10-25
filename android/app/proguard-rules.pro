# NewPipeExtractor evaluates YouTube player scripts through Rhino.
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter
-dontwarn org.mozilla.javascript.tools.**
# Desktop-only Rhino adapters are unreachable in NewPipe's interpreted mode on Android.
# See TeamNewPipe/NewPipe's upstream app/proguard-rules.pro.
-dontwarn java.beans.BeanDescriptor
-dontwarn java.beans.BeanInfo
-dontwarn java.beans.IntrospectionException
-dontwarn java.beans.Introspector
-dontwarn java.beans.PropertyDescriptor
-dontwarn jdk.dynalink.**
# Locale parsers are loaded by their generated class names.
-keep class org.schabi.newpipe.extractor.timeago.patterns.** { *; }
