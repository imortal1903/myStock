import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../database/db.dart';

/// Nome do arquivo de backup salvo no Drive.
/// Um novo backup SOBRESCREVE o anterior.
const _kNomeArquivoBackup = 'mystock_backup.db';

/// Pasta visível no Drive do usuário onde o backup é salvo.
const _kNomePasta = 'myStock';

class GoogleDriveBackupException implements Exception {
  final String mensagem;

  GoogleDriveBackupException(this.mensagem);

  @override
  String toString() => mensagem;
}

class GoogleDriveBackupService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _contaAtual;

  GoogleSignInAccount? get contaAtual => _contaAtual;

  /// Tenta recuperar silenciosamente a última conta usada.
  ///
  /// Não abre tela de login.
  Future<GoogleSignInAccount?> tentarReconectarSilenciosamente() async {
    try {
      _contaAtual = await _googleSignIn.signInSilently();
    } catch (_) {
      _contaAtual = null;
    }

    return _contaAtual;
  }

  /// Login interativo.
  ///
  /// Usado somente quando o usuário está dentro do aplicativo
  /// e realmente precisa conectar a conta.
  Future<GoogleSignInAccount> conectar() async {
    try {
      final conta = await _googleSignIn.signIn();

      if (conta == null) {
        throw GoogleDriveBackupException(
          'Login com Google cancelado.',
        );
      }

      _contaAtual = conta;

      return conta;
    } on GoogleDriveBackupException {
      rethrow;
    } catch (e) {
      throw GoogleDriveBackupException(
        'Falha ao fazer login com o Google: $e',
      );
    }
  }

  Future<void> desconectar() async {
    await _googleSignIn.signOut();
    _contaAtual = null;
  }

  /// Cria a API do Drive permitindo login interativo.
  ///
  /// É usado pelo backup manual e pelas operações feitas pela interface.
  Future<drive.DriveApi> _driveApi() async {
    if (_contaAtual == null) {
      await conectar();
    }

    final client = await _googleSignIn.authenticatedClient();

    if (client == null) {
      throw GoogleDriveBackupException(
        'Não foi possível autenticar com o Google. '
            'Tente reconectar o backup em nuvem.',
      );
    }

    return drive.DriveApi(client);
  }

  /// Cria a API do Drive exclusivamente para execução em background.
  ///
  /// IMPORTANTE:
  /// não chama signIn(), pois isso exigiria interação do usuário.
  Future<drive.DriveApi> _driveApiEmSegundoPlano() async {
    try {
      // A instância criada pelo WorkManager começa sem _contaAtual.
      // Por isso tentamos recuperar silenciosamente a sessão existente.
      _contaAtual = await _googleSignIn.signInSilently();
    } catch (e) {
      _contaAtual = null;

      throw GoogleDriveBackupException(
        'Não foi possível recuperar a conta Google em segundo plano: $e',
      );
    }

    if (_contaAtual == null) {
      throw GoogleDriveBackupException(
        'Nenhuma conta Google pôde ser recuperada em segundo plano.',
      );
    }

    final client = await _googleSignIn.authenticatedClient();

    if (client == null) {
      throw GoogleDriveBackupException(
        'Não foi possível obter autenticação do Google Drive '
            'em segundo plano.',
      );
    }

    return drive.DriveApi(client);
  }

  Future<String> _idPastaMyStock(drive.DriveApi api) async {
    try {
      final busca = await api.files.list(
        q: "mimeType='application/vnd.google-apps.folder' "
            "and name='$_kNomePasta' "
            "and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name)',
      );

      final existente = busca.files;

      if (existente != null && existente.isNotEmpty) {
        return existente.first.id!;
      }

      final criada = await api.files.create(
        drive.File(
          name: _kNomePasta,
          mimeType: 'application/vnd.google-apps.folder',
        ),
      );

      return criada.id!;
    } catch (e) {
      throw GoogleDriveBackupException(
        'Falha ao acessar a pasta "$_kNomePasta" '
            'no Google Drive: $e',
      );
    }
  }

  Future<String?> _idArquivoBackupExistente(
      drive.DriveApi api,
      String idPasta,
      ) async {
    try {
      final busca = await api.files.list(
        q: "name='$_kNomeArquivoBackup' "
            "and '$idPasta' in parents "
            "and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name)',
      );

      final existente = busca.files;

      if (existente != null && existente.isNotEmpty) {
        return existente.first.id!;
      }

      return null;
    } catch (e) {
      throw GoogleDriveBackupException(
        'Falha ao consultar o backup no Drive: $e',
      );
    }
  }

  /// Backup manual.
  ///
  /// Pode usar autenticação interativa caso necessário.
  Future<void> fazerBackup() async {
    final api = await _driveApi();

    await _enviarBackup(api);
  }

  /// Backup executado pelo WorkManager.
  ///
  /// NÃO abre login.
  /// Tenta apenas recuperar silenciosamente uma sessão Google já autorizada.
  Future<void> fazerBackupEmSegundoPlano() async {
    final api = await _driveApiEmSegundoPlano();

    await _enviarBackup(api);
  }

  /// Parte comum do envio do banco para o Google Drive.
  Future<void> _enviarBackup(drive.DriveApi api) async {
    final idPasta = await _idPastaMyStock(api);

    // Fecha a conexão antes de ler o arquivo.
    // Isso garante que os dados pendentes sejam persistidos
    // no arquivo principal do SQLite.
    await Db.instance.fecharConexao();

    final caminhoDb = await Db.instance.caminhoArquivo();
    final arquivoDb = File(caminhoDb);

    if (!await arquivoDb.exists()) {
      throw GoogleDriveBackupException(
        'Banco de dados local não encontrado.',
      );
    }

    final media = drive.Media(
      arquivoDb.openRead(),
      await arquivoDb.length(),
    );

    final idExistente = await _idArquivoBackupExistente(
      api,
      idPasta,
    );

    try {
      if (idExistente != null) {
        await api.files.update(
          drive.File(),
          idExistente,
          uploadMedia: media,
        );
      } else {
        await api.files.create(
          drive.File(
            name: _kNomeArquivoBackup,
            parents: [idPasta],
          ),
          uploadMedia: media,
        );
      }
    } catch (e) {
      throw GoogleDriveBackupException(
        'Falha ao enviar backup para o Drive: $e',
      );
    }
  }

  /// Baixa o backup mais recente do Drive e substitui o banco local.
  ///
  /// Retorna false se ainda não existir nenhum backup na nuvem.
  Future<bool> restaurarBackup() async {
    final api = await _driveApi();

    final idPasta = await _idPastaMyStock(api);
    final idArquivo = await _idArquivoBackupExistente(
      api,
      idPasta,
    );

    if (idArquivo == null) {
      return false;
    }

    final drive.Media media;

    try {
      media = await api.files.get(
        idArquivo,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
    } catch (e) {
      throw GoogleDriveBackupException(
        'Falha ao baixar backup do Drive: $e',
      );
    }

    final caminhoDb = await Db.instance.caminhoArquivo();

    await Db.instance.fecharConexao();

    // Baixa primeiro para um arquivo temporário.
    final arquivoTemp = File('$caminhoDb.restaurando');

    final sink = arquivoTemp.openWrite();

    await media.stream.pipe(sink);
    await sink.close();

    await arquivoTemp.copy(caminhoDb);
    await arquivoTemp.delete();

    return true;
  }
}