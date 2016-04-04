import ceylon.interop.java {
    javaClass,
    createJavaObjectArray,
    createJavaStringArray,
    javaString
}

import com.intellij.openapi.actionSystem {
    DataContext,
    CommonDataKeys
}
import com.intellij.openapi.application {
    Result
}
import com.intellij.openapi.command {
    WriteCommandAction
}
import com.intellij.openapi.editor {
    Document,
    Editor
}
import com.intellij.openapi.\imodule {
    ModuleUtil
}
import com.intellij.openapi.project {
    Project
}
import com.intellij.openapi.ui {
    DialogWrapper
}
import com.intellij.psi {
    PsiElement,
    PsiFile,
    PsiCodeFragment,
    PsiDocumentManager
}
import com.intellij.psi.impl.source {
    PsiTypeCodeFragmentImpl
}
import com.intellij.refactoring {
    BaseRefactoringProcessor
}
import com.intellij.refactoring.changeSignature {
    ChangeSignatureHandler,
    ChangeSignatureDialogBase,
    CallerChooserBase,
    MethodDescriptor,
    ParameterInfo,
    ParameterTableModelBase,
    ParameterTableModelItemBase
}
import com.intellij.refactoring.ui {
    ComboBoxVisibilityPanel
}
import com.intellij.ui {
    EditorTextField
}
import com.intellij.ui.treeStructure {
    IJTree=Tree
}
import com.intellij.util {
    Consumer
}
import com.intellij.util.ui {
    ColumnInfo
}
import com.intellij.util.ui.table {
    JBListTable,
    JBTableRowEditor,
    JBTableRow
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.refactoring {
    ChangeParametersRefactoring,
    getDeclarationForChangeParameters
}
import com.redhat.ceylon.ide.common.typechecker {
    AnyProjectPhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration
}

import java.awt {
    BorderLayout
}
import java.lang {
    ObjectArray
}
import java.util {
    List,
    Set,
    JArrayList=ArrayList
}

import javax.swing {
    JComponent,
    JTable
}

import org.antlr.runtime {
    CommonToken
}
import org.intellij.plugins.ceylon.ide.ceylonCode.correct {
    InsertEdit,
    TextEdit,
    TextChange,
    IdeaDocumentChanges
}
import org.intellij.plugins.ceylon.ide.ceylonCode.lang {
    CeylonFileType
}
import org.intellij.plugins.ceylon.ide.ceylonCode.model {
    IdeaCeylonProject,
    IdeaCeylonProjects
}
import org.intellij.plugins.ceylon.ide.ceylonCode.psi {
    CeylonFile
}

shared class CeylonChangeSignatureHandler() satisfies ChangeSignatureHandler {
    shared actual PsiElement? findTargetMember(PsiFile file, Editor editor) {
        return findTargetMember(file.findElementAt(editor.caretModel.offset));
    }

    shared actual PsiElement? findTargetMember(PsiElement? element) {
        if (exists element,
            is CeylonFile file = element.containingFile,
            exists node = nodes.findNode(file.compilationUnit, file.tokens, element.textOffset),
            exists d = getDeclarationForChangeParameters(node, file.compilationUnit)) {

            return element;
        }

        return null;
    }

    shared actual void invoke(Project project, ObjectArray<PsiElement>? elements, DataContext ctx) {
        if (exists editor = CommonDataKeys.\iEDITOR.getData(ctx),
            exists file = CommonDataKeys.\iPSI_FILE.getData(ctx)) {

            invoke(project, editor, file, ctx);
        }
    }

    shared actual void invoke(Project _project, Editor editor, PsiFile file, DataContext? dataContext) {
        if (is CeylonFile file) {
            value projects = _project.getComponent(javaClass<IdeaCeylonProjects>());

            if (exists mod = ModuleUtil.findModuleForFile(file.virtualFile, _project),
                is IdeaCeylonProject ceylonProject = projects.getProject(mod),
                exists node = nodes.findNode(file.compilationUnit, file.tokens, editor.selectionModel.selectionStart, editor.selectionModel.selectionEnd),
                exists decl = getDeclarationForChangeParameters(node, file.compilationUnit)) {

                value refacto = IdeaChangeParameterRefactoring(file, editor, ceylonProject, node, decl);
                if (exists params = refacto.computeParameters()) {
                    value dialog = object extends ChangeParameterDialog(params, _project) {
                        shared actual void invokeRefactoring(BaseRefactoringProcessor? processor) {
                            value chg = TextChange(editor.document);
                            refacto.build([chg, params]);

                            object extends WriteCommandAction<Nothing>(_project) {
                                shared actual void run(Result<Nothing>? result) {
                                    chg.apply(project);
                                }

                            }.execute();

                            close(DialogWrapper.\iOK_EXIT_CODE);
                        }
                    };

                    dialog.show();
                }

            }
        }
    }

    targetNotFoundMessage => "Caret should be positioned at the name of method or class to be refactored";

}

class IdeaChangeParameterRefactoring(CeylonFile file, Editor editor, IdeaCeylonProject project,
        Node node, Declaration declaration)
        satisfies ChangeParametersRefactoring<Document,InsertEdit,TextEdit,TextChange,TextChange>
                & IdeaDocumentChanges {

    addChangeToChange(TextChange change, TextChange tc) => change.addAll(tc);


    editorData = object satisfies EditorData {
        shared actual Node node => outer.node;

        shared actual Tree.CompilationUnit rootNode => file.compilationUnit;

        shared actual VirtualFile? sourceVirtualFile => null;

        shared actual List<CommonToken> tokens => file.tokens;
    };

    shared actual Boolean enabled => true;

    shared actual List<PhasedUnit> getAllUnits() => project.typechecker?.phasedUnits?.phasedUnits else nothing;

    shared actual Boolean inSameProject(Declaration decl) => true;

    newDocChange() => TextChange(file.viewProvider.document);

    newTextChange(AnyProjectPhasedUnit pu) => TextChange(pu);

    searchInEditor() => true;

    searchInFile(PhasedUnit pu) => true;

}

class MyParameterInfo(shared IdeaChangeParameterRefactoring.Param param) satisfies ParameterInfo {
    shared actual String? defaultValue => param.defaultArgs;

    shared actual String name => param.name;

    assign name {
        param.name = name;
    }

    oldIndex => -1;

    typeText => param.model.type.asString();

    shared actual variable Boolean useAnySingleVariable = false;
}

class MyMethodDescriptor(params, project) satisfies MethodDescriptor<MyParameterInfo, Object> {

    shared Project project;
    shared IdeaChangeParameterRefactoring.ParameterList params;

    canChangeName() => false;

    canChangeParameters() => true;

    canChangeVisibility() => false;

    shared actual PsiElement? method => null;

    name => params.declaration.name;

    shared actual List<MyParameterInfo> parameters = JArrayList<MyParameterInfo>();

    params.parameters.each((p) => parameters.add(MyParameterInfo(p)));

    canChangeReturnType() => ReadWriteOption.\iNone;

    parametersCount => params.size;

    shared actual Null visibility => null;

}

class MyParameterTableModel(IdeaChangeParameterRefactoring.ParameterList params, Project project)
        extends ParameterTableModelBase<MyParameterInfo, MyParameterTableModelItem>
        (null, null) {

    class MyNameColumn() extends NameColumn<MyParameterInfo, MyParameterTableModelItem>(project) {
    }
    class MyTypeColumn() extends TypeColumn<MyParameterInfo, MyParameterTableModelItem>(project, CeylonFileType.\iINSTANCE) {
        isCellEditable(MyParameterTableModelItem model) => model.parameter.param.position == -1;
    }

    alias AnyColumnInfo => ColumnInfo<out Object, out Object>;

    shared MyParameterTableModel init() {
        value typeColumn = MyTypeColumn();
        value nameColumn = MyNameColumn();

        setColumnInfos(createJavaObjectArray<AnyColumnInfo>({typeColumn, nameColumn}));

        return this;
    }

    createRowItem(MyParameterInfo? parameterInfo)
            => MyParameterTableModelItem(parameterInfo else MyParameterInfo(params.create()), project);

    shared actual void removeRow(Integer index) {
        super.removeRow(index);
        params.delete(index);
    }

    shared actual void exchangeRows(Integer oldIndex, Integer newIndex) {
        super.exchangeRows(oldIndex, newIndex);
        if (oldIndex == newIndex - 1) {
            params.moveDown(oldIndex);
        } else if (newIndex == oldIndex - 1) {
            params.moveUp(oldIndex);
        }
    }
}

class MyParameterTableModelItem(MyParameterInfo param, Project project)
        extends ParameterTableModelItemBase<MyParameterInfo>
        (param,
         PsiTypeCodeFragmentImpl(project, true, "type.ceylon", javaString(param.typeText), 0, null),
         null) {

    ellipsisType => false;
}

class ChangeParameterDialog(IdeaChangeParameterRefactoring.ParameterList params, Project project)
        extends ChangeSignatureDialogBase<MyParameterInfo,PsiElement,Object,MyMethodDescriptor,MyParameterTableModelItem,MyParameterTableModel>
        (project, MyMethodDescriptor(params, project), false, null) {

    calculateSignature() => myMethod.params.previewSignature();

    shared actual CallerChooserBase<PsiElement>? createCallerChooser(String? title,
        IJTree? treeToReuse, Consumer<Set<PsiElement>>? callback) => null;

    createParametersInfoModel(MyMethodDescriptor method)
            => MyParameterTableModel(method.params, method.project).init();

    shared actual BaseRefactoringProcessor? createRefactoringProcessor() => null;

    shared actual PsiCodeFragment? createReturnTypeCodeFragment() => null;

    createVisibilityControl()
        => ComboBoxVisibilityPanel("", createJavaObjectArray<Object>({}), createJavaStringArray({}));

    fileType => CeylonFileType.\iINSTANCE;

    shared actual String? validateAndCommitData() => null;

    listTableViewSupported => true;

    shared actual JComponent getRowPresentation(ParameterTableModelItemBase<MyParameterInfo> item, Boolean selected, Boolean focused) {
        value param = item.parameter.param;
        value text = param.model.type.asString() + " " + param.name;

        return JBListTable.createEditorTextFieldPresentation(project, CeylonFileType.\iINSTANCE,
            text, selected, focused);
    }

    getTableEditor(JTable table, ParameterTableModelItemBase<MyParameterInfo> item)
        => object extends JBTableRowEditor() {
            late variable EditorTextField myTypeEditor;
            late variable EditorTextField myNameEditor;

            shared actual ObjectArray<JComponent> focusableComponents
                    => createJavaObjectArray<JComponent>({
                        myTypeEditor.focusTarget,
                        myNameEditor.focusTarget
                    });

            shared actual JComponent preferredFocusedComponent {
                return myTypeEditor.focusTarget;
            }

            shared actual void prepareEditor(JTable tbl, Integer row) {
                this.layout = BorderLayout();
                value doc = PsiDocumentManager.getInstance(project).getDocument(item.typeCodeFragment);
                myTypeEditor = EditorTextField(doc, project, fileType);
                myTypeEditor.addDocumentListener(mySignatureUpdater);
                myTypeEditor.setPreferredWidth(table.width / 2);
                myTypeEditor.addDocumentListener(RowEditorChangeListener(0));
                myTypeEditor.setEnabled(item.parameter.param.position == -1);
                add(createLabeledPanel("Type:", myTypeEditor), javaString(BorderLayout.\iWEST));

                myNameEditor = EditorTextField(item.parameter.name, project, fileType);
                myTypeEditor.addDocumentListener(mySignatureUpdater);
                myNameEditor.addDocumentListener(RowEditorChangeListener(1));
                add(createLabeledPanel("Name:", myNameEditor), javaString(BorderLayout.\iCENTER));
            }

            shared actual JBTableRow \ivalue {
                return object satisfies JBTableRow {
                    shared actual Object? getValueAt(Integer column) {
                        return switch (column)
                        case (0) item.typeCodeFragment
                        case (1) javaString(myNameEditor.text.trimmed)
                        else null;
                    }
                };
            }
        };
}