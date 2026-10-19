import '../../../core/viewmodels/base_viewmodel.dart';
import '../services/relatorio_service.dart';

enum PeriodoPreset {
  hoje('Hoje'),
  ultimos7('7 dias'),
  ultimos30('30 dias'),
  mesAtual('Este mês'),
  tudo('Tudo'),
  personalizado('Personalizado');

  final String label;
  const PeriodoPreset(this.label);
}

enum AcaoExportacao { salvar, compartilhar }

class ResultadoExportacao {
  final bool sucesso;
  final String? mensagem;

  const ResultadoExportacao(this.sucesso, this.mensagem);
}

/// Estado da tela de exportação: qual modelo/tabelas/colunas estão
/// marcados, o período e os parâmetros, e o formato do arquivo.
class ExportarViewModel extends BaseViewModel {
  final RelatorioService _service;

  ExportarViewModel({RelatorioService? service})
      : _service = service ?? RelatorioService() {
    selecionarModelo(ModeloRelatorio.posicaoEstoque);
  }

  // Seleção

  ModeloRelatorio? _modelo;
  ModeloRelatorio? get modelo => _modelo;

  final Map<SecaoRelatorio, Set<String>> _selecao = {};

  bool get temSelecao => _selecao.isNotEmpty;
  bool secaoMarcada(SecaoRelatorio s) => _selecao.containsKey(s);
  bool colunaMarcada(SecaoRelatorio s, String colunaId) =>
      _selecao[s]?.contains(colunaId) ?? false;

  bool get usaPeriodo => _selecao.keys.any((s) => s.usaPeriodo);
  bool get usaValidade => _selecao.keys.any((s) => s.usaValidade);
  bool get usaCobertura => _selecao.keys.any((s) => s.usaCobertura);

  Set<String> _padrao(SecaoRelatorio s) => {
    for (final c in s.colunas)
      if (c.padrao) c.id,
  };

  void selecionarModelo(ModeloRelatorio m) {
    _selecao.clear();
    for (final secao in m.secoes) {
      _selecao[secao] = _padrao(secao);
    }
    _modelo = m;
    safeNotify();
  }

  void alternarSecao(SecaoRelatorio s) {
    if (_selecao.containsKey(s)) {
      _selecao.remove(s);
    } else {
      _selecao[s] = _padrao(s);
    }
    _modelo = null;
    safeNotify();
  }

  /// Marca/desmarca uma informação de uma tabela já marcada.
  void alternarColuna(SecaoRelatorio s, String colunaId) {
    final colunas = _selecao[s];
    if (colunas == null) return;

    if (!colunas.remove(colunaId)) colunas.add(colunaId);
    if (colunas.isEmpty) _selecao.remove(s);

    _modelo = null;
    safeNotify();
  }

  // Período e parâmetros

  PeriodoPreset _preset = PeriodoPreset.ultimos30;
  PeriodoPreset get preset => _preset;

  DateTime? _customDesde;
  DateTime? _customAte;

  void definirPreset(PeriodoPreset p) {
    if (p == PeriodoPreset.personalizado &&
        (_customDesde == null || _customAte == null)) {
      return;
    }
    _preset = p;
    safeNotify();
  }

  void definirPeriodoPersonalizado(DateTime desde, DateTime ate) {
    _customDesde = DateTime(desde.year, desde.month, desde.day);
    _customAte = DateTime(ate.year, ate.month, ate.day);
    _preset = PeriodoPreset.personalizado;
    safeNotify();
  }

  DateTime? get customDesde => _customDesde;
  DateTime? get customAte => _customAte;

  PeriodoRelatorio get periodo {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);

    PeriodoRelatorio ate(DateTime desde, String nome) => PeriodoRelatorio(
        desde, amanha, '$nome (${_data(desde)} a ${_data(hoje)})');

    switch (_preset) {
      case PeriodoPreset.hoje:
        return PeriodoRelatorio(hoje, amanha, 'Hoje (${_data(hoje)})');
      case PeriodoPreset.ultimos7:
        return ate(DateTime(hoje.year, hoje.month, hoje.day - 6), 'Últimos 7 dias');
      case PeriodoPreset.ultimos30:
        return ate(
            DateTime(hoje.year, hoje.month, hoje.day - 29), 'Últimos 30 dias');
      case PeriodoPreset.mesAtual:
        return ate(DateTime(hoje.year, hoje.month, 1), 'Este mês');
      case PeriodoPreset.tudo:
        return PeriodoRelatorio(
            DateTime(2000), amanha, 'Todo o período');
      case PeriodoPreset.personalizado:
        final desde = _customDesde ?? hoje;
        final fim = _customAte ?? hoje;
        return PeriodoRelatorio(
          desde,
          DateTime(fim.year, fim.month, fim.day + 1),
          '${_data(desde)} a ${_data(fim)}',
        );
    }
  }

  int _diasValidade = 30;
  int get diasValidade => _diasValidade;
  void definirDiasValidade(int dias) {
    _diasValidade = dias;
    safeNotify();
  }

  int _diasCobertura = 14;
  int get diasCobertura => _diasCobertura;
  void definirDiasCobertura(int dias) {
    _diasCobertura = dias;
    safeNotify();
  }

  // Formato e exportação
  FormatoExportacao _formato = FormatoExportacao.csv;
  FormatoExportacao get formato => _formato;
  void definirFormato(FormatoExportacao f) {
    _formato = f;
    safeNotify();
  }

  bool _exportando = false;
  bool get exportando => _exportando;

  ConfigRelatorio _config() => ConfigRelatorio(
    titulo: _modelo?.titulo ?? 'Relatório personalizado',
    arquivo: _modelo?.arquivo ?? 'relatorio',
    formato: _formato,
    selecao: {
      for (final e in _selecao.entries) e.key: Set<String>.of(e.value),
    },
    periodo: periodo,
    diasValidade: _diasValidade,
    diasCobertura: _diasCobertura,
  );

  Future<ResultadoExportacao> exportar(AcaoExportacao acao) async {
    if (_exportando || !temSelecao) {
      return const ResultadoExportacao(false, null);
    }

    _exportando = true;
    safeNotify();

    try {
      final cfg = _config();

      if (acao == AcaoExportacao.salvar) {
        final salvou = await _service.salvar(cfg);
        return ResultadoExportacao(
            salvou, salvou ? 'Relatório salvo com sucesso.' : null);
      }

      await _service.compartilhar(cfg);
      return const ResultadoExportacao(true, null);
    } catch (e) {
      return ResultadoExportacao(
          false, 'Não foi possível exportar o relatório: $e');
    } finally {
      _exportando = false;
      safeNotify();
    }
  }
}

String _dois(int n) => n.toString().padLeft(2, '0');
String _data(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}/${d.year}';