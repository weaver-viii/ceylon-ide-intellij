import com.intellij.openapi.project {
    Project
}
import com.intellij.openapi.util {
    Pair,
    Key,
    UserDataHolderBase
}
import com.intellij.psi {
    PsiManager,
    PsiModifierList,
    PsiTypeParameterList,
    PsiTypeParameter,
    PsiReferenceList,
    PsiClassType,
    PsiClass,
    PsiClassInitializer,
    PsiField,
    PsiMethod,
    PsiSubstitutor,
    PsiElement,
    PsiIdentifier,
    HierarchicalMethodSignature,
    ResolveState
}
import com.intellij.psi.impl {
    PsiClassImplUtil
}
import com.intellij.psi.impl.light {
    LightElement,
    LightModifierList
}
import com.intellij.psi.impl.source {
    ClassInnerStuffCache,
    PsiExtensibleClass
}
import com.intellij.psi.javadoc {
    PsiDocComment
}
import com.intellij.psi.scope {
    PsiScopeProcessor
}
import com.intellij.psi.util {
    PsiUtil
}
import com.intellij.util {
    IncorrectOperationException
}
import com.redhat.ceylon.ide.common.model.asjava {
    AbstractClassMirror,
    ceylonToJavaMapper
}
import com.redhat.ceylon.model.loader.mirror {
    MethodMirror,
    TypeMirror,
    TypeParameterMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    TypeDeclaration
}

import java.lang {
    ObjectArray
}
import java.util {
    ArrayList,
    Collections,
    List
}

import org.intellij.plugins.ceylon.ide.ceylonCode.lightpsi {
    CeyLightMethod,
    CeyLightTypeParameter
}
import org.intellij.plugins.ceylon.ide.ceylonCode.lang {
    CeylonLanguage
}
import org.intellij.plugins.ceylon.ide.ceylonCode.psi {
    CeylonTreeUtil
}
import com.redhat.ceylon.ide.common.model {
    CeylonUnit
}
import com.intellij.pom {
    Navigatable
}
import org.intellij.plugins.ceylon.ide.ceylonCode.resolve {
    IdeaNavigation
}
import ceylon.interop.java {
    CeylonIterable
}


List<String> toJavaModifiers(Declaration decl) {
    value modifiers = ArrayList<String>();
    
    if (decl.formal) {
        modifiers.add("abstract");
    }
    if (decl.shared) {
        modifiers.add("public");
    }
    if (is TypeDeclaration decl, decl.sealed) {
        modifiers.add("final");
    }
    return modifiers;
}

shared class CeyLightClass extends LightElement
        satisfies PsiExtensibleClass & CeylonLightElement {

    AbstractClassMirror mirror;
    variable ClassInnerStuffCache? lazyInnersCache = null;

    shared new(Declaration decl, Project project)
            extends LightElement(PsiManager.getInstance(project), CeylonLanguage.instance) {
        assert(is AbstractClassMirror mir = ceylonToJavaMapper.mapDeclaration(decl).first);
        this.mirror = mir;
        "The declaration must be in a Ceylon unit"
        assert(is CeylonUnit unit = mir.decl.unit);
    }

    shared new fromMirror(AbstractClassMirror mirror, Project project)
            extends LightElement(PsiManager.getInstance(project), CeylonLanguage.instance) {
        "The declaration must be in a Ceylon unit"
        assert(is CeylonUnit unit = mirror.decl.unit);
        this.mirror = mirror;
    }

    shared actual Declaration declaration {
        return mirror.decl;
    }

    value modifiers = CeylonIterable(toJavaModifiers(declaration));

    shared actual PsiModifierList modifierList {
        return LightModifierList(manager, language, *modifiers);
    }

    shared actual Boolean hasModifierProperty(String name) {
        return modifiers.contains(name);
    }

    shared actual PsiDocComment? docComment {
        return null;
    }

    shared actual Boolean deprecated {
        return mirror.decl.deprecated;
    }

    shared actual Boolean hasTypeParameters() {
        return !mirror.typeParameters.empty;
    }

    shared actual PsiTypeParameterList? typeParameterList {
        return null;
    }

    shared actual ObjectArray<PsiTypeParameter> typeParameters {
        List<TypeParameterMirror> list = mirror.typeParameters;
        ObjectArray<PsiTypeParameter> params = ObjectArray<PsiTypeParameter>(list.size());
        variable Integer i = 0;
        for (TypeParameterMirror mirror in list) {
            params.set(i++, CeyLightTypeParameter(mirror, manager));
        }
        return params;
    }

    qualifiedName => mirror.qualifiedName;

    \iinterface => mirror.\iinterface;

    annotationType => mirror.annotationType;

    enum => mirror.enum;

    shared actual PsiReferenceList? extendsList => null;

    shared actual PsiReferenceList? implementsList => null;

    extendsListTypes => PsiClassType.emptyArray;

    implementsListTypes => PsiClassType.emptyArray;

    shared actual PsiClass? superClass {
        if (mirror.superclass exists) {
            // TODO?
            print(mirror.superclass);
        }
        return null;
    }

    interfaces => PsiClass.emptyArray;

    supers => PsiClass.emptyArray;

    shared actual ObjectArray<PsiClassType> superTypes {
        value superTypes = ArrayList<PsiClassType>();
        if (exists sup = mirror.superclass) {
            superTypes.add(createType(sup, project));
        }
        for (TypeMirror intf in mirror.interfaces) {
            superTypes.add(createType(intf, project));
        }
        if (superTypes.size() == 0) {
            return PsiClassType.emptyArray;
        } else {
            return superTypes.toArray(PsiClassType.arrayFactory.create(superTypes.size()));
        }
    }

    fields => myInnersCache.fields;

    methods => myInnersCache.methods;

    constructors => myInnersCache.constructors;

    innerClasses => myInnersCache.innerClasses;

    initializers => PsiClassInitializer.emptyArray;

    allFields => PsiClassImplUtil.getAllFields(this);

    allMethods => PsiClassImplUtil.getAllMethods(this);

    allInnerClasses => PsiClass.emptyArray;

    shared actual PsiField? findFieldByName(String name, Boolean checkBases) => null;

    shared actual PsiMethod? findMethodBySignature(PsiMethod patternMethod, Boolean checkBases)
            => null;

    findMethodsBySignature(PsiMethod patternMethod, Boolean checkBases) => PsiMethod.emptyArray;

    findMethodsByName(String name, Boolean checkBases) => PsiMethod.emptyArray;

    findMethodsAndTheirSubstitutorsByName(String name, Boolean checkBases)
            => Collections.emptyList<Pair<PsiMethod,PsiSubstitutor>>();

    allMethodsAndTheirSubstitutors
            => Collections.emptyList<Pair<PsiMethod,PsiSubstitutor>>();

    shared actual PsiClass? findInnerClassByName(String name, Boolean checkBases) => null;

    shared actual PsiElement? lBrace => null;

    shared actual PsiElement? rBrace => null;

    shared actual PsiIdentifier? nameIdentifier => null;

    shared actual PsiElement? scope => null;

    isInheritor(PsiClass baseClass, Boolean checkDeep) => false;

    isInheritorDeep(PsiClass baseClass, PsiClass classToByPass) => false;

    shared actual PsiClass? containingClass => null;

    visibleSignatures => Collections.emptyList<HierarchicalMethodSignature>();

    shared actual PsiElement setName(String name) {
        throw IncorrectOperationException("Not supported");
    }

    containingFile => CeylonTreeUtil.getDeclaringFile(mirror.decl.unit, project);

    name => mirror.name;

    string => "CeyLightClass:" + mirror.name;

    shared actual List<PsiField> ownFields {
        return Collections.emptyList<PsiField>();
    }

    shared actual List<PsiMethod> ownMethods {
        value methods = ArrayList<PsiMethod>();
        for (MethodMirror meth in mirror.directMethods) {
            methods.add(CeyLightMethod(this, meth, project));
        }
        return methods;
    }

    shared actual List<PsiClass> ownInnerClasses {
        value classes = ArrayList<PsiClass>();
        for (cls in mirror.directInnerClasses) {
            assert(is AbstractClassMirror cls);
            classes.add(fromMirror(cls, project));
        }
        return classes;
    }

    ClassInnerStuffCache myInnersCache
            => lazyInnersCache else (lazyInnersCache = ClassInnerStuffCache(this));

    shared actual Boolean processDeclarations(PsiScopeProcessor processor, ResolveState state,
        PsiElement lastParent, PsiElement place) {

        return PsiClassImplUtil.processDeclarationsInClass(this, processor, state, null,
            lastParent, place, PsiUtil.getLanguageLevel(place), false);
    }

    shared actual void navigate(Boolean requestFocus) {
        if (is Navigatable nav = IdeaNavigation(project).gotoDeclaration(declaration)) {
            nav.navigate(requestFocus);
        }
    }

    // Ambiguous members inherited from multiple parents
    valid => (super of LightElement).valid;

    writable => (super of LightElement).writable;

    shared actual T getCopyableUserData<T>(Key<T>? key)
            given T satisfies Object
            => (super of UserDataHolderBase).getCopyableUserData(key);

    shared actual void putCopyableUserData<T>(Key<T>? key, T? val)
            given T satisfies Object {
        (super of UserDataHolderBase).putCopyableUserData(key, val);
    }

    shared actual PsiElement? navigationElement => (super of LightElement).navigationElement;
    assign navigationElement {
        (super of LightElement).navigationElement = navigationElement;
    }
}